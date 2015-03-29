module blindfire.net;


import core.time : dur;
import std.string : format;
import std.stdio : writefln;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.conv : to;

import blindfire.log : Logger;
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

struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state;

	//list of connected peers as a hashmap, identified by their UUID
	Peer[ClientID] peers;

	Tid game_thread;
	ClientID client_uuid;
	ushort port;

	Logger!("NET", ConnectionState) logger;

	this(ushort port, Tid game_tid, ClientID uuid) {

		//set socket to nonblocking, since one thread is used both for transmission and receiving, doesn't block on receive.
		this.socket = new UdpSocket();
		this.socket.blocking = false;

		//thread id to pass messages back to
		this.game_thread = game_tid;
		
		//unique network identifier
		this.client_uuid = uuid;
		this.port = port;

		this.logger = Logger!("NET", ConnectionState)(&state);

	}

	void send_packet(T, Args...)(MessageType type, Address target, Args args) {
		auto success = socket.sendTo(cast(void[T.sizeof])T(type, args), target);
		string type_str = to!string(type);
		logger.log((success == Socket.ERROR)
			? format("Failed to send %s packet.", type_str)
			: "Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());
	}

	void send_data_packet(UpdateMessage msg, immutable(ubyte)[] data, Address target) {
		StaticArray!(ubyte, 2048) send_data;
		send_data ~= cast(ubyte[msg.sizeof])msg;
		send_data ~= cast(ubyte[])data;
		auto success = socket.sendTo(cast(void[])send_data.array[0..send_data.elements], target);
		string type_str = to!string(msg.type);
		logger.log((success == Socket.ERROR)
			? format("Failed to send %s packet.", type_str)
			: "Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());
	}


	//attempts to bind to a port, increments port number if binding fails.
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
			if (bytes != -1) logger.log("Received %d bytes", bytes);

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
								logger.log("Client %s sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);
								send(game_thread, Command.UPDATE, cast(immutable(ubyte)[])data[umsg.sizeof..umsg.sizeof+umsg.data_size].idup);
								break;

							case MessageType.DISCONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %s sent disconnect message.", cmsg.client_uuid);
								peers.remove(cmsg.client_uuid);
								break;

							default:
								logger.log("Unhandled message: %s", to!string(type));

						}
					}

					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd, immutable(ubyte)[] data) { //handle updates sent from game thread
						logger.log("Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.UPDATE:
								logger.log("Sending Game State Update: %d bytes", data.length);
								foreach (id, peer; peers) {
									auto msg = UpdateMessage(MessageType.UPDATE, client_uuid, cast(uint)data.length);
									send_data_packet(msg, data, peer.addr);
								}
								break;
							case Command.TERMINATE:
								open = false;
								break;
							default:
								logger.log("Unhandled Command: %s", to!string(cmd));
						}
					},
					(Command cmd) {
						logger.log("Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.DISCONNECT:
								logger.log("Sending disconnect message.");
								foreach (id, peer; peers)
									send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, client_uuid);
								foreach (key; peers.keys) peers.remove(key);
								state = ConnectionState.UNCONNECTED;
								break;
							default:
								logger.log("Unhandled Command: %s", to!string(cmd));
						}
					});

					break;

				case ConnectionState.UNCONNECTED:

					if (msg) {
						switch (type) {
							case MessageType.CONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Connection from %s at %s:%s", cmsg.client_uuid, from.toAddrString(), from.toPortString());
								ClientID id = cmsg.client_uuid;

								if (id !in peers) {
									Peer new_peer = {client_uuid: id, addr: from};
									send_packet!(BasicMessage)(MessageType.CONNECT, from, client_uuid);
									peers[id] = new_peer;
								} else {
									logger.log("Already in connected peers.");
								}

								send(game_thread, Command.CREATE);
								state = ConnectionState.CONNECTED;
								break;

							case MessageType.PING:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %s sent ping, sending pong.", cmsg.client_uuid);
								send_packet!(BasicMessage)(MessageType.PONG, from, client_uuid);
								break;

							case MessageType.PONG:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %s sent pong.", cmsg.client_uuid);
								break;

							default:
								logger.log("Unhandled message: %s", to!string(type));

						}
					}
			
					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd, shared(InternetAddress) addr) {
						logger.log("Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.CONNECT:
								logger.log("Entering Connect.");
								auto target = cast(InternetAddress)addr;
								send_packet!(BasicMessage)(MessageType.CONNECT, target, client_uuid);
								break;
							default:
								logger.log("Unhandled Command: %s", to!string(cmd));
						}
					},
					(Command cmd) {
						logger.log("Received command: %s", to!string(cmd));
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
								logger.log("Unhandled command: %s", to!string(cmd));
						}
					});

					break;

				case ConnectionState.WAITING:

					if (msg) {
						switch (type) {

							case MessageType.CONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Connection from %s at: %s:%s", cmsg.client_uuid, from.toAddrString(), from.toPortString());
								ClientID id = cmsg.client_uuid;

								if (id !in peers) {
									Peer new_peer = {client_uuid: id, addr: from};
									send_packet!(BasicMessage)(MessageType.CONNECT, from, client_uuid);
									peers[id] = new_peer;
								} else {
									logger.log("Already in connected peers.");
								}

								send(game_thread, Command.CREATE);
								state = ConnectionState.CONNECTED;
								break;

							case MessageType.PING:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %S sent ping, sending pong.", cmsg.client_uuid);
								send_packet!(BasicMessage)(MessageType.PONG, from, client_uuid);
								break;

							case MessageType.PONG:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %S sent pong.", cmsg.client_uuid);
								break;

							default:
								logger.log("Unhandled message: %s", to!string(type));

						}

					}

					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd) {
						logger.log("Received command: %s", to!string(cmd));
						switch (cmd) {
							case Command.DISCONNECT:
								logger.log("Sending disconnect message.");
								foreach (id, peer; peers)
									send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, client_uuid);
								foreach (key; peers.keys) peers.remove(key);
								state = ConnectionState.UNCONNECTED;
								break;
							case Command.TERMINATE:
								open = false;
								break;
							default:
								logger.log("Unhandled command: %s", to!string(cmd));
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
