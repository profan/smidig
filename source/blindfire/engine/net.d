module blindfire.engine.net;

import core.time : dur;
import std.string : format;
import std.stdio : writefln;
import std.datetime : StopWatch;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.conv : to;

import blindfire.engine.log : Logger;
import blindfire.engine.defs : ClientID;
import blindfire.engine.stream : InputStream, OutputStream;

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
	PONG,

	GET_PEER_LIST,
	SEND_PEER_LIST

} //MessageType

enum ConnectionState {

	CONNECTED, //not accepting connections, active
	UNCONNECTED, //not accepting connections, can create
	CONNECTING //accepting connections, has created session or is in created lobby

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
} //MessageHeader

struct BasicMessage {

	this(MessageType type, ClientID client) {
		this.type = type;
		this.client_uuid = client;
	}

	align(1):
	mixin MessageHeader;

} //BasicMessage

struct ConnectMessage {

	this(MessageType type, ClientID client, ClientID assigned_id) {
		this.type = type;
		this.client_uuid = client;
		this.assigned_id = assigned_id;
	}

	align(1):
	mixin MessageHeader;
	ClientID assigned_id;

} //ConnectMessage

struct UpdateMessage {

	this(MessageType type, ClientID client, uint data_size) {
		this.type = type;
		this.client_uuid = client;
		this.data_size = data_size;
	}

	align(1):
	mixin MessageHeader;
	uint data_size;

} //UpdateMessage

struct Peer {

	ClientID client_uuid;
	Address addr;

} //Peer

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
} //NetworkState

struct NetworkPeer {

	enum DEFAULT_CLIENT_ID = ClientID.max;
	enum MAX_PACKET_SIZE = 65507;

	bool open;
	UdpSocket socket;
	ConnectionState state = ConnectionState.UNCONNECTED;

	ushort port;
	bool is_host = false;
	Peer[ClientID] peers; //list of connected peers as a hashmap, identified by their UUID
	ClientID client_uuid;
	Tid game_thread;

	NetworkState net_state;
	Logger!("NET", NetworkState) logger;

	ClientID id_counter;
	Peer host_peer;

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
		auto obj = T(type, args);
		auto bytes_sent = socket.sendTo((cast(void*)&obj)[0..obj.sizeof], target);
		string type_str = to!string(type);
		logger.log((bytes_sent == Socket.ERROR)
			? format("Failed to send %s packet.", type_str)
			: "Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());

		network_stats.total_bytes_out += bytes_sent;
	}

	void send_data_packet(UpdateMessage msg, immutable(ubyte)[] data, Address target) {
		ubyte[4096] ubyte_data = void; //FIXME look at this later
		auto send_data = OutputStream(ubyte_data);
		send_data.write(msg);
		send_data.write(data);
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

	void handle_connect(ref InputStream stream, Address from) {

		auto cmsg = stream.read!ConnectMessage();
		logger.log("Connection from %s at: %s:%s", cmsg.client_uuid, from.toAddrString(), from.toPortString());
		
		ClientID id = cmsg.client_uuid;

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

		if (state == ConnectionState.CONNECTING) {
			state = switch_state(ConnectionState.CONNECTED);
			send(game_thread, Command.SET_CONNECTED);
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
			id_counter = 0;
		}

		return new_state;
	}

	void handle_connected_net(MessageType type, ref InputStream stream, Address from) { //is connected.

		switch (type) {

			case MessageType.CONNECT:
				handle_connect(stream, from);
				break;

			case MessageType.DISCONNECT:

				auto cmsg = stream.read!BasicMessage();								
				logger.log("Client %s sent disconnect message.", cmsg.client_uuid);

				if (!is_host && host_peer.client_uuid == cmsg.client_uuid) { //if disconnecting client is the host, disconnect too.
					state = switch_state(ConnectionState.UNCONNECTED);
					send(game_thread, Command.DISCONNECT);
				}

				peers.remove(cmsg.client_uuid);
				break;

			case MessageType.UPDATE:
				
				auto umsg = stream.read!UpdateMessage();
				logger.log("Client %s sent update message, payload size: %d bytes", umsg.client_uuid, umsg.data_size);

				if (umsg.client_uuid !in peers) {
					logger.log("Unconnected client %s sent update message, payload size: %d bytes",
							   umsg.client_uuid, umsg.data_size);
					break;
				}

				send(game_thread, Command.UPDATE,
					 cast(immutable(ubyte)[])stream.pointer[0..umsg.data_size].idup);
				//this cast is not useless, DO NOT REMOVE THIS UNLESS YOU ACTUALLY FIX THE PROBLEM
				break;

			default:
				logger.log("Unhandled message type: %s", to!string(type));

		}

	}

	void handle_connected_command(Command cmd) {

		switch (cmd) with (Command) {

			case DISCONNECT:
				handle_disconnect();
				break;

			default:
				handle_common(cmd);

		}

	}

	void handle_connected_command_update(Command cmd, immutable(ubyte)[] data) {

		switch (cmd) with (Command) {

			case UPDATE:

				logger.log("Sending Game State Update: %d bytes", data.length);

				foreach (id, peer; peers) {
					auto msg = UpdateMessage(MessageType.UPDATE, client_uuid, cast(uint)data.length);
					send_data_packet(msg, data, peer.addr);
				}

				break;

			default:
				handle_common(cmd);

		}

	}

	void handle_connected() {

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_connected_command,
			&handle_connected_command_update
		);

	}

	void handle_unconnected_net(MessageType type, InputStream stream, Address from) { //not yet connected, not trying to establish a connection.

		switch (type) {
			default:
				logger.log("Unhandled message type: %s", to!string(type));
		}

	}

	void handle_unconnected_command(Command cmd) {

		switch (cmd) with (Command) {

			case CREATE: //new session, become ze host

				this.client_uuid = 0;
				this.id_counter = 0;
				this.is_host = true;
				this.state = switch_state(ConnectionState.CONNECTED);

				send(game_thread, Command.ASSIGN_ID, id_counter++);
				break;

			default:
				handle_common(cmd);

		}

	}

	void handle_unconnected_command_addr(Command cmd, shared(InternetAddress) addr) {

		switch (cmd) with (Command) {

			case CONNECT:

				auto target = cast(InternetAddress)addr;
				peers[0] = Peer(0, target); //add "host" to peers
				state = switch_state(ConnectionState.CONNECTING);
				send_packet!(ConnectMessage)(MessageType.CONNECT, target, client_uuid, DEFAULT_CLIENT_ID);
				break;

			default:
				handle_common(cmd, addr);

		}

	}

	void handle_unconnected() {

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_unconnected_command,
			&handle_unconnected_command_addr
		);

	}

	void handle_connecting_net(MessageType type, ref InputStream stream, Address from) { //waiting to successfully establish a connection.

		switch (type) {

			case MessageType.CONNECT:
				handle_connect(stream, from);
				break;

			default:
				logger.log("Unhandled message type: %s", to!string(type));

		}

	}

	void handle_connecting_command(Command cmd) {

		switch (cmd) with (Command) {

			case DISCONNECT:
				handle_disconnect();
				break;

			default:
				handle_common(cmd);

		}

	}

	void handle_connecting() {

		auto result = receiveTimeout(dur!("nsecs")(1),
			&handle_connecting_command
		);

	}

	void handle_common(Command cmd) {

		switch (cmd) {

			case Command.PING:
				//send ping to all connected peers
				foreach (ref peer; peers) {
					send_packet!(BasicMessage)(MessageType.PING, peer.addr, client_uuid);
				}
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

	void update_stats(size_t bytes_in) {

		if (bytes_in != -1) {
			logger.log("Received %d bytes", bytes_in);
			network_stats.total_bytes_in += bytes_in;	
		}

		network_stats.update_stats();

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
					if (packet_ready) { handle_connected_net(type, stream, from); }
					handle_connected();
					break;

				case UNCONNECTED:
					if (packet_ready) { handle_unconnected_net(type, stream, from); }
					handle_unconnected();
					break;

				case CONNECTING:
					if (packet_ready) { handle_connecting_net(type, stream, from); }
					handle_connecting();
					break;

			}

		}

	}

} //NetworkPeer

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
