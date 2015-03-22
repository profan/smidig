module sundownstandoff.net;

import core.time : dur;
import std.string : format;
import std.stdio : writefln;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.conv : to;

enum MessageType : uint {

	CONNECT,
	DISCONNECT,
	UPDATE,
	PING,
	PONG,

} //MessageType

alias ClientID = uint;

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

struct Message {

	align(1):
	MessageType type;
	ClientID client_id;
	uint content_size;
	void[] content;

}

struct BasicMessage {

	this(MessageType type, ClientID client) {
		this.type = type;
		this.client_id = client;
	}

	align(1):
	MessageType type;
	ClientID client_id;

}

struct Peer {

	uint client_id;
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
	T variable;

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
	ushort port;

	Self self;
	Tid game_thread;

	this(ushort port, Tid game_tid) {

		this.socket = new UdpSocket();
		this.socket.blocking = false;
		this.state = ConnectionState.UNCONNECTED;
		this.game_thread = game_tid;
		this.port = port;

	}

	void send_packet(T, Args...)(MessageType type, Address target, Args args) {
		auto success = socket.sendTo(cast(void[T.sizeof])T(type, args), target);
		string type_str = to!string(type);
		writefln((success == Socket.ERROR)
			? format("[NET] Failed to send %s packet.", type_str)
			: "[NET] Sent %s packet to %s:%s", type_str, target.toAddrString(), target.toPortString());
	}

	//recieve all the shit, handle connections as well
	void listen() {
	
		//dear god, don't make me go to straight up C based sockets
		Address addr;
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

		scope(exit) { socket.close(); }
		self[0] = addr;
		Peer p = {client_id: port};
		self[1] = p;

		open = true;
		writefln("[NET] Listening on localhost:%d", port);

		Address from; //will point to address received from, also port
		void[1024] data = void;
		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			if (bytes != -1) writefln("[NET] Recieved %d bytes", bytes);

			if (bytes >= cast(typeof(bytes))MessageType.sizeof) {
				MessageType type = *(cast(MessageType*)data);

				switch (type) with (MessageType) {
					case CONNECT:
						BasicMessage cmsg = *(cast(BasicMessage*)(data));
						writefln("[NET] Connection from %s:%s", from.toAddrString(), from.toPortString());
						ClientID id = to!ClientID(from.toPortString());
						Peer new_peer = {client_id: id, addr: from};

						if (id !in peers) {
							send_packet!(BasicMessage)(CONNECT, from, port);
							peers[id] = new_peer;
						} else {
							writefln("[NET] Already in connected peers.");
						}

						if (state != ConnectionState.CONNECTED) {
							send(game_thread, Command.CREATE);
							state = ConnectionState.CONNECTED;
						}

						break;
					case DISCONNECT:
						BasicMessage cmsg = *(cast(BasicMessage*)(data));
						writefln("[NET] Client %d sent disconnect message.", cmsg.client_id);
						peers.remove(cmsg.client_id);
						break;
					case PING:
						BasicMessage cmsg = *(cast(BasicMessage*)(data));
						writefln("[NET] Client %d sent ping, sending pong.", cmsg.client_id);
						send_packet!(BasicMessage)(PONG, from, port);
						break;
					case PONG:
						BasicMessage cmsg = *(cast(BasicMessage*)(data));
						writefln("[NET] Client %d sent pong.", cmsg.client_id);
						break;
					default:
						writefln("[NET] Recieved unhandled message type: %s", to!string(type));
						break;
				}
			}

			auto result = receiveTimeout(dur!("nsecs")(1),
			(Command cmd, shared(InternetAddress) addr) {
				writefln("[NET] Command: %s", to!string(cmd));
				switch(cmd) with (Command) {
					case CONNECT:
						writefln("[NET] Entering Connect.");
						auto target = cast(InternetAddress)addr;
						send_packet!(BasicMessage)(MessageType.CONNECT, target, port);
						Peer new_peer = {client_id: target.port, addr: target};
						peers[target.port] = new_peer;
						break;
					default:
						writefln("[NET] Unhandled Command: %s", to!string(cmd));
						break;
				}
			},
			(Command cmd) {
				writefln("[NET] Command: %s", to!string(cmd));
				switch (cmd) with (Command) {
					case CREATE:
						send(game_thread, Command.CREATE);
						break;
					case DISCONNECT:
						writefln("[NET] Sending disconnect message.");
						foreach (id, peer; peers)
							send_packet!(BasicMessage)(MessageType.DISCONNECT, peer.addr, port);
						foreach (key; peers.keys) peers.remove(key);
						state = ConnectionState.UNCONNECTED;
						break;
					case PING:
						foreach (id, peer; peers)
							send_packet!(BasicMessage)(MessageType.PING, peer.addr, port);
						break;
					case TERMINATE:
						writefln("[NET] Terminating Thread.");
						open = false;
						break;
					default:
						writefln("[NET] Unhandled Command: %s", to!string(cmd));
						break;
				}
			});

		}

	}


} //NetworkPeer

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
