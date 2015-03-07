module sundownstandoff.net;

import std.stdio : writefln;
import std.socket : InternetAddress, Socket, TcpSocket;
import std.concurrency;

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

}

enum Command {

	CREATE,
	CONNECT,
	DISCONNECT,
	TERMINATE

}


// Will live in a thread which the game sends and receives messages from!
struct NetworkPeer {

	bool open;
	TcpSocket socket;
	ConnectionState state;
	ushort port = 12000;

	Socket[] peers;

	this(ushort port) {

		this.socket = new TcpSocket();
		this.socket.bind(new InternetAddress("localhost", port));
		this.state = ConnectionState.UNCONNECTED;
		this.port = port;

	}

	void listen() {

		this.open = true;
		writefln("[NET] Listening on localhost:%d", port);

		auto msg = receiveOnly!(Command);
		writefln("[NET] Command: %d", msg);

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

void launch_peer() {

	auto peer = NetworkPeer(12000);
	peer.listen();

}
