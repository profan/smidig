module sundownstandoff.net;

import std.stdio : writefln;
import std.socket : InternetAddress, Socket, UdpSocket, SocketException;
import std.concurrency : receiveOnly, Tid;
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


//recieves messages, owns a thread which sends messages
struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state;
	ushort port = 12000;
	Socket[] peers;

	Tid game_thread;

	this(ushort port, Tid game_tid) {

		this.socket = new UdpSocket();
		this.state = ConnectionState.UNCONNECTED;
		this.game_thread = game_tid;
		this.port = port;

	}

	//send all the shit
	void broadcast() {

	}

	//recieve all the shit, handle connections as well
	void listen() {
	
		try {
			socket.bind(new InternetAddress("localhost", port));
		} catch (SocketException e) {
			writefln("[NET] Failed to bind to localhost:%d, retrying with localhost:%d", port, port+1);
			socket.bind(new InternetAddress("localhost", cast(ushort)(port+1)));
			port += 1;
		}

		open = true;
		writefln("[NET] Listening on localhost:%d", port);

		auto msg = receiveOnly!(Command);
		writefln("[NET] Command: %s", to!string(msg));

		if (msg == Command.TERMINATE) {
			writefln("[NET] Terminating Thread.");
			return;
		}

		while (open) {
			socket.listen(1);
			peers ~= socket.accept();
		}

	}

} //NetworkPeer

void launch_peer(Tid game_tid) {

	auto peer = NetworkPeer(12000, game_tid);
	peer.listen();

}
