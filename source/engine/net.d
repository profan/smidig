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

import blindfire.defs : ClientID;

enum MessageType : uint {

	CONNECT,
	DISCONNECT,
	UPDATE,
	PING,
	PONG,

} //MessageType

enum ConnectionState {

	CONNECTED,
	UNCONNECTED,
	WAITING

} //ConnectionState

enum Command {

	//set ecs id
	ASSIGN_ID,

	CREATE,
	CONNECT,
	DISCONNECT,
	TERMINATE,
	UPDATE,
	STATS,
	PING

} //Command


/******************************
* Packet Structure ************
*
* 	Type
*	ClientID
*	Content-Size
*	Content
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

struct ConnectMessage {

	this(MessageType type, ClientID client, ClientID assigned_id) {
		this.type = type;
		this.client_uuid = client;
		this.assigned_id = assigned_id;
	}

	align(1):
	mixin MessageHeader;
	ClientID assigned_id;

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

struct NetVar(T) {

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

	void opAssign(T rhs) {
		changed = true;
		variable = rhs;
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

struct NetworkState {
	ConnectionState* state;
	ubyte* client_uuid;

	string toString() {
		return to!string(*state) ~ " " ~ to!string(*client_uuid);
	}
}

struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state = ConnectionState.UNCONNECTED;

	//keep track of if Peer is host as well?
	bool is_host = false;

	//list of connected peers as a hashmap, identified by their UUID
	Peer[ClientID] peers;

	Tid game_thread;
	ClientID client_uuid;
	ushort port;

	NetworkState net_state;
	Logger!("NET", NetworkState) logger;

	this(ushort port, Tid game_tid) {

		//set socket to nonblocking, since one thread is used both for transmission and receiving, doesn't block on receive.
		this.socket = new UdpSocket();
		this.socket.blocking = false;

		//thread id to pass messages back to
		this.game_thread = game_tid;
		
		//unique network identifier
		this.client_uuid = 255; //if it's still 255 when in session, something is wrong.
		this.port = port;

		this.net_state = NetworkState();
		net_state.state = &state;
		net_state.client_uuid = &client_uuid;
		this.logger = Logger!("NET", NetworkState)(&net_state);

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
				addr = new InternetAddress(InternetAddress.ADDR_ANY, port);
				socket.bind(addr);
				break;
			} catch (SocketException e) {
				writefln("[NET] Failed to bind to localhost:%d, retrying with localhost:%d", port, port+1);
				port += 1;
			}
		}

	}

	void handle_disconnect() {

		logger.log("Sending disconnect message.");
		foreach (id, peer; peers)
			send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, client_uuid);
		foreach (key; peers.keys) //creates an array of keys from the hashmap's keys
			peers.remove(key);
		state = switch_state(ConnectionState.UNCONNECTED);

	}

	ConnectionState switch_state(ConnectionState new_state) {
		logger.log("Switching state to: %s", to!string(new_state));

		//set this back to false!
		if (new_state == ConnectionState.UNCONNECTED) {
			is_host = false;
		}

		return new_state;
	}

	//rewritten
	void listen() {

		Address addr;
		bind_to_port(addr);

		open = true;
		logger.log("Listening on localhost:%d", port);

		Peer host_peer; //reference to current host, not used if self is host, otherwise queried for certain information.

		ubyte id_counter;
		Address from; //used to keep track of who message was received from
		void[4096] data = void;
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

								if (umsg.client_uuid !in peers) {
									logger.log("Unconnected client %s sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);
									break;
								}

								logger.log("Client %s sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);
								send(game_thread, Command.UPDATE, cast(immutable(ubyte)[])data[umsg.sizeof..umsg.sizeof+umsg.data_size].idup); //this cast is not useless, DO NOT REMOVE THIS UNLESS YOU ACTUALLY FIX THE PROBLEM
								break;

							case MessageType.DISCONNECT:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %s sent disconnect message.", cmsg.client_uuid);

								if (!is_host && host_peer.client_uuid == cmsg.client_uuid) { //if disconnecting client is the host, disconnect too.
									state = switch_state(ConnectionState.UNCONNECTED);
									send(game_thread, Command.DISCONNECT);
								}

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
								handle_disconnect();
								break;
							default:
								logger.log("Unhandled Command: %s", to!string(cmd));
						}
					});

					break;

				case ConnectionState.UNCONNECTED:

					if (msg) {
						switch (type) {

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
					(Command cmd, shared(InternetAddress) to_addr) {
						logger.log("Command: %s", to!string(cmd));
						switch (cmd) {
							case Command.CONNECT:
								logger.log("Entering Connect.");
								auto target = cast(InternetAddress)to_addr;
								send_packet!(ConnectMessage)(MessageType.CONNECT, target, client_uuid, cast(ubyte)255);
								state = switch_state(ConnectionState.WAITING);
								break;
							default:
								logger.log("Unhandled Command: %s", to!string(cmd));
						}
					},
					(Command cmd) {
						logger.log("Received command: %s", to!string(cmd));
						switch (cmd) {
							case Command.CREATE:
								state = switch_state(ConnectionState.WAITING);
								client_uuid = 0;
								id_counter = 0;
								is_host = true;
								send(game_thread, Command.ASSIGN_ID, id_counter++);
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
								ConnectMessage cmsg = *(cast(ConnectMessage*)(data));
								logger.log("Connection from %s at: %s:%s", cmsg.client_uuid, from.toAddrString(), from.toPortString());
								
								ClientID id = cmsg.client_uuid;
								if (id == client_uuid) {
									logger.log("Can't connect to self.");
									state = switch_state(ConnectionState.UNCONNECTED);
									send(game_thread, Command.DISCONNECT);
									break;
								}

								if (id !in peers) {
									Peer new_peer = {client_uuid: id_counter, addr: from};
									send_packet!(ConnectMessage)(MessageType.CONNECT, from, client_uuid, id_counter++);
									peers[cast(ubyte)(id_counter-1)] = new_peer;
								} else {
									logger.log("Already in connected peers.");
								}

								if (!is_host) {
									host_peer = Peer(cmsg.client_uuid, from);
									client_uuid = cmsg.assigned_id;
									send(game_thread, Command.CREATE);
									send(game_thread, Command.ASSIGN_ID, cmsg.assigned_id);
								}

								state = switch_state(ConnectionState.CONNECTED);
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
								handle_disconnect();
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

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
