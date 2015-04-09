module blindfire.netgame;

import blindfire.netmsg;

enum SessionState {
	INACTIVE, //not waiting for players, not running
	RUNNING, //game running
	WAITING, //waiting for players, in lobby
}

class NetworkManager {

	SessionState state;

	this() {
		state = SessionState.INACTIVE;
	}

	void handle_messages() {

	}

	void send_message(ubyte[] data) {

	}

} //NetworkManager

class Session {

	NetworkManager nm;

	this(NetworkManager nm) {
		
	}

} //Session
