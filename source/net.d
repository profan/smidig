module sundownstandoff.net;

import core.time : dur;
import std.stdio : writefln;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, send, Tid;
import std.typecons : Tuple;
import std.conv : to;

enum MessageType : uint {

	CONNECT,
	DISCONNECT,
	PING,
	PONG,
	MOVE,
	FIRE

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
	TERMINATE

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

struct ConnectionMessage {

	align(1):
	MessageType type = MessageType.CONNECT;

}

struct Peer {

	uint client_id;
	Address addr;

}

struct NetVar(T) {

	alias variable this;
	bool changed = false;
	T variable;

	T opUnary(string op)() if (s == "++" || s == "--") {
		changed = true;
		mixin("return " ~ op ~ " variable;");
	}

	T opOpAssign(string op)(T rhs) {
		mixin("return variable " ~ op ~ "= rhs;");
	}

	T opBinary(string op)(T rhs) {
		changed = true;
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

	void send_connection_packet(Address target) {
		auto success = socket.sendTo(cast(void[ConnectionMessage.sizeof])ConnectionMessage(), target);
		writefln((success == Socket.ERROR)
			? "[NET] Failed to send connection packet."
			: "[NET] Sent connection packet to %s:%s", target.toAddrString(), target.toPortString());
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

		auto msg = receiveOnly!(Command); //wait for create or connect command
		writefln("[NET] Command: %s", to!string(msg));

		switch (msg) with (Command) {
			case CREATE:
				send(game_thread, Command.CREATE);
				break;
			case CONNECT:
				writefln("[NET] Entering Connect.");
				auto ia = receiveOnly!(shared(InternetAddress));
				auto target = cast(InternetAddress)ia;
				send_connection_packet(target);
				Peer new_peer = {client_id: target.port, addr: target};
				peers[target.port] = new_peer;
				break;
			case TERMINATE:
				writefln("[NET] Terminating Thread.");
				return;
			default:
				writefln("[NET] Unhandled Command: %s", to!string(msg));
				break;
		}

		Address from; //will point to address received from, also port
		void[1024] data = void;
		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			if (bytes != -1) writefln("[NET] Recieved %d bytes", bytes);

			if (bytes >= cast(typeof(bytes))MessageType.sizeof) {
				MessageType type = *(cast(MessageType*)data);
				if (type == MessageType.CONNECT) {
					ConnectionMessage cmsg = *(cast(ConnectionMessage*)(data));
					writefln("[NET] Connection from %s:%s", from.toAddrString(), from.toPortString());
					ClientID id = to!ClientID(from.toPortString());
					Peer new_peer = {client_id: id, addr: from};
					if (id !in peers) {
						send_connection_packet(from);
						peers[id] = new_peer;
					}
				} else {
					writefln("[NET] Recieved unhandled message type: %s", to!string(type));
				}
			}

			auto result = receiveTimeout(dur!("nsecs")(1),
			(Command cmd) {
				writefln("[NET] Command: %s", to!string(cmd));
				switch (cmd) with (Command) {
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
