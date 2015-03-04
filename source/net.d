module sundownstandoff.net;

import std.socket : InternetAddress, TcpSocket;

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


// Will live in a thread which the game sends and receives messages from!
class NetworkPeer {

	bool open;
	TcpSocket socket;
	ConnectionState state;

	this(short port) {

		this.socket = new TcpSocket();
		this.socket.bind(new InternetAddress("localhost", 12000));
		this.state = ConnectionState.UNCONNECTED;

	}

	void listen() {
		this.open = true;
		while (open) {
			socket.listen(1);
		}
	}

} //NetworkPeer
