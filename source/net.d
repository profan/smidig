module sundownstandoff.net;

import std.socket : InternetAddress, TcpSocket;

enum MessageType {

	CONNECT,
	DISCONNECT,
	MOVE,
	FIRE

} //MessageType


// Will live in a thread which the game sends and receives messages from!
struct NetworkPeer {

	bool open;
	TcpSocket socket;

	this(short port) {

		this.socket = new TcpSocket();
		this.socket.bind(new InternetAddress("localhost", 12000));

	}

	void listen() {
		this.open = true;
		while (open) {
			socket.listen(1);
		}
	}

} //NetworkPeer
