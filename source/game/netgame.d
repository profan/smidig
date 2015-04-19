module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout;
import std.datetime : dur;

import blindfire.engine.stream : InputStream;

import blindfire.engine.net;
import blindfire.engine.log;

alias void delegate() OnConnectDelegate;
alias void delegate() OnDisconnectDelegate;

struct PlayerData {

	char[64] player_name;

} //PlayerData 

enum UpdateType {

	JOIN

}

alias TurnID = uint;

class GameNetworkManager {

	enum Event {
		CONNECT,
		DISCONNECT
	}

	enum State {
		SESSION_ACTIVE
	}

	TurnID turn_id;
	Tid network_thread;

	this(Tid net_tid) {
		this.network_thread = net_tid;
	}

	void handle_messages() {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {

			writefln("[GAME] Recieved %s from net thread.", to!string(cmd));

			switch (cmd) with (Command) {

				case CREATE:
					break;

				case DISCONNECT:
					break;

				default:
					writefln("[GAME] Unhandled message from net thread: %s", to!string(cmd));
					break;

			}

		},
		(Command cmd, ClientID assigned_id) {
			if (cmd == Command.ASSIGN_ID) {
				writefln("[GAME] Recieved id assignment: %d from net thread.", assigned_id);
				//assign the id!
			}
		},
		(Command cmd, immutable(ubyte)[] data) {

			bool done = false;
			auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

			writefln("[GAME_NET] Received packet, %d bytes", data.length);

			UpdateType type = input_stream.read!UpdateType();
			while (!done && input_stream.current < data.length) {

				switch (type) {

					default:
						writefln("[GAME_NET] Unhandled Update Type: %s", to!string(type));
						done = true; //halt, or would get stuck in a loop.

				}

			}

		});

	}

	void send_message(Args...)(Args args) {

		send(network_thread, args);

	}

	void send_message(in ubyte[] data) {

		//copy data, send.
		send(network_thread, data.idup);

	}

} //GameNetworkManager

struct Session {

	enum State {
		RUNNING,
		WAITING
	}

	GameNetworkManager nm;

	this(GameNetworkManager nm) {
		
	}

} //Session
