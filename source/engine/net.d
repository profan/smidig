module sundownstandoff.net;

import core.time : dur;
import std.string : format;
import std.stdio : writefln;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.conv : to;

import profan.collections : StaticArray;

enum MessageType : uint {

	CONNECT,
	DISCONNECT,
	UPDATE,
	PING,
	PONG,

} //MessageType

import std.uuid : UUID;
alias ClientID = UUID;

enum ConnectionState {

	CONNECTED,
	UNCONNECTED,
	WAITING

} //ConnectionState

enum Command {

	CREATE,
	CONNECT,
	DISCONNECT,
	TERMINATE,
	UPDATE,
	PING

} //Command


/******************************
* Packet Structure ************
*
* 	Type: 32 bits
*	ClientID: 32 bits
*	Content-Size: 32 bits
*	Content: Content-Size
*
******************************/

mixin template MessageHeader() {
	MessageType type;
	ClientID client_uuid;
}

struct BasicMessage {

	this(MessageType type, ClientID client) {
		this.type = type;
		this.client_uuid = client;
	}

	align(1):
	mixin MessageHeader;

}

struct UpdateMessage {

	this(MessageType type, ClientID client, uint data_size) {
		this.type = type;
		this.client_uuid = client;
		this.data_size = data_size;
	}

	align(1):
	mixin MessageHeader;
	uint data_size;

}

struct Peer {

	ClientID client_uuid;
	Address addr;

}

enum Owner {
	LOCAL,
	REMOTE
}

struct NetVar(T) {

	Owner owner = Owner.LOCAL;
	alias variable this;
	bool changed = false;
	
	union {
		T variable;
		ubyte[T.sizeof] bytes;
	}

	this(T var) {
		this.variable = var;
	}

	T opUnary(string op)() if (s == "++" || s == "--") {
		changed = true;
		mixin("return " ~ op ~ " variable;");
	}

	void opOpAssign(string op)(T rhs) {
		changed = true;
		mixin("variable " ~ op ~ "= rhs;");
	}

	T opBinary(string op)(T rhs) {
		mixin("return variable " ~ op ~ " rhs;");
	}

} //NetVar


alias Self = Tuple!(Address, Peer);

//recieves messages, owns a thread which sends messages
struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state;
	Peer[ClientID] peers;
	ClientID client_uuid;
	ushort port;

	Self self;
	Tid game_thread;

	this(ushort port, Tid game_tid, ClientID uuid) {

		this.socket = new UdpSocket();
		this.socket.blocking = false;
		this.state = ConnectionState.UNCONNECTED;
		this.game_thread = game_tid;
		this.client_uuid = uuid;
		this.port = port;

	}

	void send_packet(T, Args...)(MessageType type, Address target, Args args) {
		auto success = socket.sendTo(cast(void[T.sizeof])T(type, args), target);
		string type_str = to!string(type);
		writefln((success == Socket.ERROR)
			? format("[NET] Failed to send %s packet.", type_str)
			: "[NET] Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());
	}

	void send_data_packet(UpdateMessage msg, immutable(ubyte)[] data, Address target) {
		StaticArray!(ubyte, 2048) send_data;
		send_data ~= cast(ubyte[msg.sizeof])msg;
		send_data ~= cast(ubyte[])data;
		auto success = socket.sendTo(cast(void[])send_data.array[0..send_data.elements], target);
		string type_str = to!string(msg.type);
		writefln((success == Socket.ERROR)
			? format("[NET] Failed to send %s packet.", type_str)
			: "[NET] Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());
	}

	void bind_to_port(out Address addr) {

		while(true) {
			try {
				addr = new InternetAddress("localhost", port);
				socket.bind(addr);
				break;
			} catch (SocketException e) {
				writefln("[NET] Failed to bind to localhost:%d, retrying with localhost:%d", port, port+1);
				port += 1;
			}
		}

	}

	//rewritten
	void listen() {

		Address addr;
		bind_to_port(addr);

		open = true;
		state = ConnectionState.UNCONNECTED;
		writefln("[NET] Listening on localhost:%d", port);

		Address from; //used to keep track of who message was received from
		void[2048] data = void;
		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			if (bytes != -1) writefln("[NET] Received %d bytes", bytes);

			bool msg; //if msg is set, theres a packet to be handled.
			MessageType type;
			if (bytes >= cast(typeof(bytes))MessageType.sizeof) {
				type = *(cast(MessageType*)data);
				msg = true;
			} else {
				msg = false;
			}

			final switch (state) {
				case ConnectionState.CONNECTED:

					if (msg) {
						switch (type) {

							case MessageType.UPDATE:
								//take slice from sizeof(header) to sizeof(header) + header.data_length and send
								UpdateMessage umsg = *(cast(UpdateMessage*)(data));
								writefln("[NET] (CONNECTED) Client %d sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);
								send(game_thread, Command.UPDATE, cast(immutable(ubyte)[])data[umsg.sizeof..umsg.sizeof+umsg.data_size].idup);
								break;

							case MessageType.DISCONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (CONNECTED) Client %d sent disconnect message.", cmsg.client_uuid);
								peers.remove(cmsg.client_uuid);
								break;

							default:
								writefln("[NET] (CONNECTED) Unhandled message: %s", to!string(type));

						}
					}

					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd, immutable(ubyte)[] data) { //handle updates sent from game thread
						writefln("[NET] (CONNECTED) Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.UPDATE:
								writefln("[NET] (CONNECTED) Sending Game State Update: %d bytes", data.length);
								foreach (id, peer; peers) {
									auto msg = UpdateMessage(MessageType.UPDATE, client_uuid, cast(uint)data.length);
									send_data_packet(msg, data, peer.addr);
								}
								break;
							case Command.TERMINATE:
								open = false;
								break;
							default:
								writefln("[NET] (CONNECTED) Unhandled Command: %s", to!string(cmd));
						}
					},
					(Command cmd) {
						writefln("[NET] (CONNECTED) Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.DISCONNECT:
								writefln("[NET] (CONNECTED) Sending disconnect message.");
								foreach (id, peer; peers)
									send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, client_uuid);
								foreach (key; peers.keys) peers.remove(key);
								state = ConnectionState.UNCONNECTED;
								break;
							default:
								writefln("[NET] (CONNECTED) Unhandled Command: %s", to!string(cmd));
						}
					});

					break;

				case ConnectionState.UNCONNECTED:

					if (msg) {
						switch (type) {
							case MessageType.CONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (UNCONNECTED) Connection from %s:%s", from.toAddrString(), from.toPortString());
								ClientID id = cmsg.client_uuid;

								if (id !in peers) {
									Peer new_peer = {client_uuid: id, addr: from};
									send_packet!(BasicMessage)(MessageType.CONNECT, from, client_uuid);
									peers[id] = new_peer;
								} else {
									writefln("[NET] (UNCONNECTED) Already in connected peers.");
								}

								send(game_thread, Command.CREATE);
								state = ConnectionState.CONNECTED;
								break;

							case MessageType.PING:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (UNCONNECTED) Client %d sent ping, sending pong.", cmsg.client_uuid);
								send_packet!(BasicMessage)(MessageType.PONG, from, client_uuid);
								break;

							case MessageType.PONG:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (UNCONNECTED) Client %d sent pong.", cmsg.client_uuid);
								break;

							default:
								writefln("[NET] (UNCONNECTED) Unhandled message: %s", to!string(type));

						}
					}
			
					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd, shared(InternetAddress) addr) {
						writefln("[NET] (UNCONNECTED) Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.CONNECT:
								writefln("[NET] (UNCONNECTED) Entering Connect.");
								auto target = cast(InternetAddress)addr;
								send_packet!(BasicMessage)(MessageType.CONNECT, target, client_uuid);
								break;
							default:
								writefln("[NET:2] Unhandled Command: %s", to!string(cmd));
						}
					},
					(Command cmd) {
						writefln("[NET] (UNCONNECTED) Received command: %s", to!string(cmd));
						switch (cmd) {
							case Command.CREATE:
								state = ConnectionState.WAITING;
								break;							
							case Command.TERMINATE:
								open = false;
								break;
							case Command.PING:
								foreach (id, peer; peers)
									send_packet!(BasicMessage)(MessageType.PING, peer.addr, client_uuid);
								break;
							default:
								writefln("[NET] (UNCONNECTED) Unhandled command: %s", to!string(cmd));
						}
					});

					break;

				case ConnectionState.WAITING:

					if (msg) {
						switch (type) {

							case MessageType.CONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (WAITING) Connection from %s:%s", from.toAddrString(), from.toPortString());
								ClientID id = cmsg.client_uuid;

								if (id !in peers) {
									Peer new_peer = {client_uuid: id, addr: from};
									send_packet!(BasicMessage)(MessageType.CONNECT, from, client_uuid);
									peers[id] = new_peer;
								} else {
									writefln("[NET] (WAITING) Already in connected peers.");
								}

								send(game_thread, Command.CREATE);
								state = ConnectionState.CONNECTED;
								break;

							case MessageType.PING:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (WAITING) Client %d sent ping, sending pong.", cmsg.client_uuid);
								send_packet!(BasicMessage)(MessageType.PONG, from, client_uuid);
								break;

							case MessageType.PONG:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								writefln("[NET] (WAITING) Client %d sent pong.", cmsg.client_uuid);
								break;

							default:
								writefln("[NET] (WAITING) Unhandled message: %s", to!string(type));

						}

					}

					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd) {
						writefln("[NET] (WAITING) Received command: %s", to!string(cmd));
						switch (cmd) {
							case Command.DISCONNECT:
								writefln("[NET] (WAITING) Sending disconnect message.");
								foreach (id, peer; peers)
									send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, client_uuid);
								foreach (key; peers.keys) peers.remove(key);
								state = ConnectionState.UNCONNECTED;
								break;
							case Command.TERMINATE:
								open = false;
								break;
							default:
								writefln("[NET] (WAITING) Unhandled command: %s", to!string(cmd));
						}
					});

					break;

			}

		}

	}

} //NetworkPeer

void launch_peer(Tid game_tid, ClientID uuid) {

	auto peer = NetworkPeer(12000, game_tid, uuid);
	peer.listen();

}
