module blindfire.engine.net;

import core.time : dur;
import std.string : format;
import std.stdio : writefln;
import std.datetime : StopWatch;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.algorithm : each;
import std.conv : to;

import blindfire.engine.log : Logger;
import blindfire.engine.defs : ClientID;
import blindfire.engine.stream : InputStream;

import profan.collections : StaticArray;

struct NetworkStats {

	StopWatch timer;
	float last_bytes_in = 0.0f;
	float last_bytes_out = 0.0f;

	size_t total_bytes_in = 0;
	size_t total_bytes_out = 0;

	float bytes_in_per_second = 0.0f;
	float bytes_out_per_second = 0.0f;

	float messages_in_per_second = 0.0f;
	float messages_out_per_second = 0.0f;

} //NetworkStats

__gshared NetworkStats network_stats;

private void update_stats(ref NetworkStats stats) {

	if (stats.timer.peek().seconds == 0) return;

	stats.bytes_in_per_second = cast(float)stats.total_bytes_in / cast(float)stats.timer.peek().seconds;
	stats.bytes_in_per_second = stats.bytes_in_per_second * 0.9f + stats.last_bytes_in * 0.1f;
	stats.last_bytes_in = stats.bytes_in_per_second;

	stats.bytes_out_per_second = cast(float)stats.total_bytes_out / cast(float)stats.timer.peek().seconds;
	stats.bytes_out_per_second = stats.bytes_out_per_second * 0.9f + stats.last_bytes_out * 0.1f;
	stats.last_bytes_out = stats.bytes_out_per_second;

}

enum MessageType : uint {

	START,
	CONNECT,
	DISCONNECT,
	UPDATE,
	PING,
	PONG

} //MessageType

enum ConnectionState {

	CONNECTED, //not accepting connections, active
	UNCONNECTED, //not accepting connections, can create
	WAITING //accepting connections, has created session or is in created lobby

} //ConnectionState

enum Command {

	//set network id
	ASSIGN_ID,

	CREATE,
	CONNECT,
	DISCONNECT,
	TERMINATE,
	UPDATE,
	PING,

	//replacement commands
	SET_CONNECTED,
	SET_UNCONNECTED,

	//notifications to game thread
	NOTIFY_CONNECTION

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
	ClientID* client_uuid;

	string toString() {
		return to!string(*state) ~ " " ~ to!string(*client_uuid);
	}
}

struct NetworkPeer {

	enum DEFAULT_CLIENT_ID = ClientID.max;
	enum MAX_PACKET_SIZE = 65507;

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

	Peer host_peer;
	ClientID id_counter;

	this(ushort port, Tid game_tid) {

		//set socket to nonblocking, since one thread is used both for transmission and receiving, doesn't block on receive.
		this.socket = new UdpSocket();
		this.socket.blocking = false;

		//thread id to pass messages back to
		this.game_thread = game_tid;
		
		//unique network identifier
		this.client_uuid = DEFAULT_CLIENT_ID; //if it's still 255 when in session, something is wrong.
		this.port = port;

		this.net_state = NetworkState();
		net_state.state = &state;
		net_state.client_uuid = &client_uuid;
		this.logger = Logger!("NET", NetworkState)(&net_state);

	}

	void send_packet(T, Args...)(MessageType type, Address target, Args args) {
		auto bytes_sent = socket.sendTo(cast(void[T.sizeof])T(type, args), target);
		string type_str = to!string(type);
		logger.log((bytes_sent == Socket.ERROR)
			? format("Failed to send %s packet.", type_str)
			: "Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());

		network_stats.total_bytes_out += bytes_sent;

	}

	void send_data_packet(UpdateMessage msg, immutable(ubyte)[] data, Address target) {
		StaticArray!(ubyte, 4096) send_data;
		send_data ~= cast(ubyte[msg.sizeof])msg;
		send_data ~= data;
		auto bytes_sent = socket.sendTo(cast(void[])send_data[], target);
		string type_str = to!string(msg.type);
		logger.log((bytes_sent == Socket.ERROR)
			? format("Failed to send %s packet.", type_str)
			: "Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());

		network_stats.total_bytes_out += bytes_sent;

	}


	//attempts to bind to a port, increments port number if binding fails.
	void bind_to_port(out Address addr) {

		while(true) {
			try {
				addr = new InternetAddress(InternetAddress.ADDR_ANY, port);
				socket.bind(addr);
				break;
			} catch (SocketException e) {
				logger.log("[NET] Failed to bind to localhost:%d, retrying with localhost:%d", port, port+1);
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

	auto switch_state(ConnectionState new_state) {
		logger.log("Switching state to: %s", to!string(new_state));

		//set this back to false!
		if (new_state == ConnectionState.UNCONNECTED) {
			is_host = false;
		}

		return new_state;
	}

	//rewritten

	void handle_connected_net(MessageType type, InputStream stream, Address from) { //is connected.

		switch (type) {
			case MessageType.CONNECT:
				auto msg = stream.read!ConnectMessage();
				break;
			case MessageType.DISCONNECT:
				auto msg = stream.read!BasicMessage();
				break;
			default:
				logger.log("Unhandled message type: %s", to!string(type));
		}
		//much connected

	}

	void handle_connected() {

		void handle_command(Command cmd) {
			switch (cmd) with (Command) {
				case DISCONNECT:
					handle_disconnect();
					break;
				default:
					handle_common(cmd);
			}
		}

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_command
		);

	}

	void handle_unconnected_net(MessageType type, InputStream stream, Address from) { //not yet connected, not trying to establish a connection.

		switch (type) {
			default:
				logger.log("Unhandled message type: %s", to!string(type));
		}
		//wow such unconnected

	}

	void handle_unconnected() {

		void handle_command(Command cmd) {
			switch (cmd) with (Command) {
				case CREATE: //new session, become ze host
					state = switch_state(ConnectionState.CONNECTED);
					client_uuid = 0;
					id_counter = 0;
					is_host = true;
					send(game_thread, Command.ASSIGN_ID, id_counter++);
					break;
				default:
					handle_common(cmd);
			}
		}

		void handle_command_addr(Command cmd, shared(InternetAddress) addr) {
			switch (cmd) with (Command) {
				case CONNECT:
					auto target = cast(InternetAddress)addr;
					send_packet!(ConnectMessage)(MessageType.CONNECT, target, client_uuid, DEFAULT_CLIENT_ID);
					state = switch_state(ConnectionState.WAITING);
					peers[0] = Peer(0, target);
					break;
				default:
					handle_common(cmd, addr);
			}
		}

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_command,
			&handle_command_addr
		);

	}

	void handle_waiting_net(MessageType type, InputStream stream, Address from) { //waiting to successfully establish a connection.

		switch (type) {
			case MessageType.CONNECT:
				auto msg = stream.read!ConnectMessage();
				break;
			default:
				logger.log("Unhandled message type: %s", to!string(type));
		}
		//handle shit

	}

	void handle_waiting() {

		void handle_command(Command cmd) {
			switch (cmd) with (Command) {
				case DISCONNECT:
					handle_disconnect();
					break;
				default:
					handle_common(cmd);
			}
		}

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_command
		);

	}

	void handle_common(Command cmd) {

		switch (cmd) {
			case Command.PING:
				//send ping to all connected peers
				peers.each!(peer => send_packet!(BasicMessage)(MessageType.PING, peer.addr, client_uuid));
				break;
			case Command.TERMINATE:
				open = false;
				break;
			default:
				logger.log("Common - Unhandled command: %s", to!string(cmd));
		}

	}

	void handle_common(Command cmd, shared(InternetAddress) addr) {

		switch (cmd) {
			default:
				logger.log("Common - Unhandled command: %s : %s", to!string(cmd), cast(InternetAddress)addr);
		}

	}

	void listen() {

		Address addr;
		bind_to_port(addr);

		open = true;
		logger.log("Listening on - %s:%d", addr.toAddrString(), port);
		network_stats.timer.start();

		Address from;

		import core.stdc.stdlib : malloc, free;
		void[] data = malloc(MAX_PACKET_SIZE)[0..MAX_PACKET_SIZE];
		scope (exit) { free(data.ptr); }

		void update_stats(size_t bytes) {
			if (bytes != -1) {
				logger.log("Received %d bytes", bytes);
				network_stats.total_bytes_in += bytes;	
			} 
			network_stats.update_stats();
		}

		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			update_stats(bytes);

			bool packet_ready = (bytes != -1 && bytes >= MessageType.sizeof);
		
			InputStream stream;
			MessageType type;

			if (packet_ready) {
				stream = InputStream(cast(ubyte*)data.ptr, bytes);
				type = stream.read!(MessageType, InputStream.ReadMode.Peek)();
				logger.log("Received message of type: %s", to!string(type));
			}

			final switch (state) with (ConnectionState) {
				case CONNECTED:
					(packet_ready) ? {
						handle_connected_net(type, stream, from); handle_connected();
					} : handle_connected();
					break;
				case UNCONNECTED:
					(packet_ready) ? {
						handle_unconnected_net(type, stream, from); handle_unconnected();
					} : handle_unconnected();
					break;
				case WAITING:
					(packet_ready) ? {
						handle_waiting_net(type, stream, from); handle_waiting();
					} : handle_waiting();
					break;
			}

		}

	}

	/*
	void listen() {

		Address addr;
		bind_to_port(addr);

		open = true;
		logger.log("Listening on localhost:%d", port);
		network_stats.timer.start();

		Peer host_peer; //reference to current host, not used if self is host, otherwise queried for certain information.

		ClientID id_counter;
		Address from; //used to keep track of who message was received from
		void[4096] data = void;

		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			if (bytes != -1) {
				logger.log("Received %d bytes", bytes);
				network_stats.total_bytes_in += bytes;
			}
				
			network_stats.update_stats();

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
									logger.log("Unconnected client %s sent update message, payload size: %d bytes", 
										umsg.client_uuid, umsg.data_size);
									break;
								}

								logger.log("Client %s sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);
								send(game_thread, Command.UPDATE, 
									cast(immutable(ubyte)[])data[umsg.sizeof..umsg.sizeof+umsg.data_size].idup); 
									//this cast is not useless, DO NOT REMOVE THIS UNLESS YOU ACTUALLY FIX THE PROBLEM
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
							case Command.TERMINATE:
								open = false;
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
								send_packet!(ConnectMessage)(MessageType.CONNECT, target, client_uuid, cast(ClientID)255);
								state = switch_state(ConnectionState.WAITING);
								send(game_thread, Command.CONNECT);
								peers[0] = Peer(0, target);
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
									peers[cast(ClientID)(id_counter-1)] = new_peer;

									if (is_host) {
										send(game_thread, Command.NOTIFY_CONNECTION, id_counter-1);
									}

								} else {
									logger.log("Already in connected peers.");
								}

								if (!is_host) {
									host_peer = Peer(cmsg.client_uuid, from);
									client_uuid = cmsg.assigned_id;
									send(game_thread, Command.ASSIGN_ID, cmsg.assigned_id);
								}

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

							case MessageType.START:
								BasicMessage cmsg = *(cast(BasicMessage*)(data));
								logger.log("Client %s sent start.", cmsg.client_uuid);
								send(game_thread, Command.SET_CONNECTED);
								break;

							default:
								logger.log("Unhandled message: %s", to!string(type));

						}

					}

					auto result = receiveTimeout(dur!("nsecs")(1),
					(Command cmd) {
						logger.log("Received command: %s", to!string(cmd));
						switch (cmd) {
							case Command.SET_CONNECTED:
								foreach (peer; peers) {
									send_packet!(BasicMessage)(MessageType.START, from, peer.client_uuid);
								}
								state = switch_state(ConnectionState.CONNECTED);
								break;
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

			import core.thread : Thread;
			Thread.sleep(dur!("usecs")(1));

		}

	}*/

} //NetworkPeer

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
