module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout;
import std.datetime : dur;

import blindfire.net;
import blindfire.netmsg;
import blindfire.log;

enum SessionState {
	INACTIVE, //not waiting for players, not running
	RUNNING, //game running
	WAITING, //waiting for players, in lobby
}

alias void delegate() OnConnectDelegate;
alias void delegate() OnDisconnectDelegate;

class NetworkManager {

	enum Event {
		CONNECT,
		DISCONNECT
	}

	Tid network_thread;
	SessionState state;

	this(Tid network_thread) {
		state = SessionState.INACTIVE;
	}

	void handle_messages() {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {

		});

	}

	void send_message(ubyte[] data) {

	}

} //NetworkManager

class Session {

	NetworkManager nm;

	this(NetworkManager nm) {
		
	}

} //Session
