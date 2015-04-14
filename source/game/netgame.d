module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout;
import std.datetime : dur;

import blindfire.engine.stream : InputStream;

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

		},
		(Command cmd, immutable(ubyte)[] data) {

			bool done = false;
			auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

			writefln("[GAME_NET] Received packet, %d bytes", data.length);

			UpdateType type = input_stream.read!UpdateType();
			while (!done && input_stream.current < data.length) {

				switch (type) {

					case UpdateType.CREATE, UpdateType.UPDATE, UpdateType.DESTROY:
						break;

					default:
						writefln("[GAME_NET] Unhandled Update Type: %d", type);
						done = true; //halt, or would get stuck in a loop.

				}

			}

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
