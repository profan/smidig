module sundownstandoff.net;

import std.stdio : writefln;
import std.socket : InternetAddress, Socket, UdpSocket;
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


// Will live in a thread which the game sends and receives messages from!
struct NetworkPeer {

	bool open;
	UdpSocket socket;
	ConnectionState state;
	ushort port = 12000;
	Socket[] peers;

	Tid game_thread;

	this(ushort port, Tid game_tid) {

		this.socket = new UdpSocket();
		this.socket.bind(new InternetAddress("localhost", port));
		this.state = ConnectionState.UNCONNECTED;
		this.port = port;

		this.game_thread = game_tid;

	}

	void listen() {

		this.open = true;
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
