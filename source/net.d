module sundownstandoff.net;

import core.time : dur;
import std.stdio : writefln;
import std.socket : Address, InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, receiveTimeout, Tid;
import std.conv : to;

enum MessageType {

	CONNECT,
	DISCONNECT,
	MOVE,
	FIRE

} //MessageType

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
*	Content-Length: 32 bits
*	Content: Content-Length
*
******************************/

struct Message {

	uint type;
	uint client_id;
	uint content_len;
	void[] content;

}

struct Peer {

	uint client_id;
	Address address;

}

//recieves messages, owns a thread which sends messages
struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state;
	ushort port = 12000;
	Peer[] peers;

	Tid game_thread;

	this(ushort port, Tid game_tid) {

		this.socket = new UdpSocket();
		this.socket.blocking = false;
		this.state = ConnectionState.UNCONNECTED;
		this.game_thread = game_tid;
		this.port = port;

	}

	//send all the shit
	void broadcast() {

	}

	//recieve all the shit, handle connections as well
	void listen() {
	
		//dear god, don't make me go to straight up C based sockets
		try {
			socket.bind(new InternetAddress("localhost", port));
		} catch (SocketException e) {
			writefln("[NET] Failed to bind to localhost:%d, retrying with localhost:%d", port, port+1);
			socket.bind(new InternetAddress("localhost", ++port));
		}

		open = true;
		writefln("[NET] Listening on localhost:%d", port);

		auto msg = receiveOnly!(Command);
		writefln("[NET] Command: %s", to!string(msg));

		if (msg == Command.TERMINATE) {
			writefln("[NET] Terminating Thread.");
			return;
		}

		Address from;
		void[1024] data = void;
		while (open) {

			auto bytes = socket.receiveFrom(data, from);
			if (bytes != -1) writefln("[NET] Recieved %d bytes", bytes);

			auto result = receiveTimeout(dur!("nsecs")(1),
			(Command cmd) {
				writefln("[NET] Command: %s", to!string(cmd));
				if (cmd == Command.TERMINATE) {
					writefln("[NET] Terminating Thread.");
					open = false;
				}
			});

		}

	}


} //NetworkPeer

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
