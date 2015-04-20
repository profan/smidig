module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout, send;
import std.datetime : dur;

import blindfire.engine.stream : InputStream;
import blindfire.engine.log;
import blindfire.engine.net;

import blindfire.action;

import profan.ecs : EntityManager;

alias void delegate() OnConnectDelegate;
alias void delegate() OnDisconnectDelegate;

struct PlayerData {

	char[64] player_name;

} //PlayerData

alias TempBuf = StaticArray!(ubyte, 2048);

alias ActionType = uint;
interface Action {

	ActionType identifier() const;
	void serialize(ref TempBuf buf);
	void execute(EntityManager em);

} //Action

enum UpdateType {

	ACTION

} //UpdateType

alias TurnID = uint;
class TurnManager {

	Action[] pending_actions;

	void create_action(T, Args...)(Args args) {
		pending_actions ~= new T(args);
	}

	void do_pending_actions(EntityManager em) {

		foreach (ref action; pending_actions) {
			action.execute(em);
		}

		pending_actions = [];

	}

} //TurnManager

class GameNetworkManager {

	enum Event {
		CONNECT,
		DISCONNECT
	}

	enum State {
		SESSION_ACTIVE
	}

	float turn_length = 0.2f;
	float tick_length = 0.05f;
	uint ticks_per_second = 20;
	uint ticks_per_turn = 4;

	TurnID turn_id;
	private Tid network_thread;
	TurnManager tm;
	EntityManager em;

	OnConnectDelegate[] on_connect;

	this(Tid net_tid) {
		this.network_thread = net_tid;
		this.tm = new TurnManager();
	}

	bool lockstep_turn() {

		if (next_turn()) {

			send_pending_actions();

			if (turn_id >= 3) {
				//process_actions();
			}

		}

		return false;

	}

	bool next_turn() {

		//ready to go to next turn? return true? :D
		return false;

	}

	void send_pending_actions() {

	}

	StaticArray!(ubyte, 2048) buf;
	void process_actions() {

		buf.length = 0;
		foreach (action; tm.pending_actions) {

			auto type = UpdateType.ACTION;
			buf ~= (cast(ubyte*)&type)[0..type.sizeof];

			auto id = action.identifier();
			buf ~= (cast(ubyte*)&id)[0..ActionType.sizeof];
			action.serialize(buf);

		}
	
		if (buf.length > 0)	{
			send(network_thread, Command.UPDATE, cast(immutable(ubyte[]))buf[].idup);
		}

		tm.do_pending_actions(em);

	}

	void handle_messages() {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {

			writefln("[GAME] Recieved %s from net thread.", to!string(cmd));

			switch (cmd) with (Command) {

				case CREATE:

					foreach (del; on_connect) {
						del();
					}

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

			import blindfire.serialize : deserialize;

			bool done = false;
			auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

			writefln("[GAME] Received packet, %d bytes", data.length);

			UpdateType type = input_stream.read!UpdateType();
			while (!done && input_stream.current < data.length) {

				switch (type) {

					string handle_action() {

						auto str = "";

						foreach (type, id; ActionIdentifier) {
							str ~= "case " ~ to!string(id) ~ ": " ~
								type ~ " action = new " ~ type ~ "();" ~
								"deserialize!("~type~")(input_stream, &action);" ~
								"action.execute(em); break;";
						}

						return str;

					}

					case UpdateType.ACTION:

						ActionType action_type = input_stream.read!(ActionType)();
						switch (action_type) {

							mixin(handle_action());

							default:
								writefln("[GAME] Unhandled action type: %s", to!string(action_type));
								break;
						}

						break;

					default:
						writefln("[GAME] Unhandled Update Type: %s", to!string(type));
						done = true; //halt, or would get stuck in a loop.

				}

			}

		});

	}

	void send_message(Args...)(Args args) {

		send(network_thread, args);

	}

	void send_action(T, Args...)(Args args) {

		tm.create_action!(T)(args);

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
