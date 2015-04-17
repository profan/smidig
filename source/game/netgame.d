module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout;
import std.datetime : dur;

import blindfire.engine.stream : InputStream;

import blindfire.engine.net;
import blindfire.netmsg;
import blindfire.engine.log;

alias void delegate() OnConnectDelegate;
alias void delegate() OnDisconnectDelegate;

class GameNetworkManager {

	enum Event {
		CONNECT,
		DISCONNECT
	}

	enum State {
		SESSION_ACTIVE
	}

	Tid network_thread;

	this(Tid network_thread) {
	
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

struct Session {

	enum State {
		RUNNING,
		WAITING
	}

	GameNetworkManager nm;

	this(GameNetworkManager nm) {
		
	}

} //Session
