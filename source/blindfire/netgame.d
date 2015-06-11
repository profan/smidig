module blindfire.netgame;

import std.concurrency : Tid, receiveTimeout, send;
import std.datetime : dur;

import blindfire.engine.stream : InputStream, OutputStream;
import blindfire.engine.state : GameState, GameStateHandler;
import blindfire.engine.log;
import blindfire.engine.net;

import blindfire.action;
import blindfire.config;
import profan.ecs : EntityManager;

struct PlayerData {

	ubyte length;
	char[64] player_name;

} //PlayerData

alias TempBuf = OutputStream;
alias ActionType = uint;

interface Action {

	ActionType identifier() const;
	void serialize(ref TempBuf buf);
	void execute(EntityManager em);

} //Action

enum UpdateType {

	ACTION,
	PLAYER_DATA

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

struct Connection {
	StaticArray!(char, 64) player_name;
}

class GameNetworkManager {

	struct Server {
		StaticArray!(char, 64) server_name;
	}

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
	TurnManager tm;
	EntityManager em;
	private Tid network_thread;

	ClientID client_id;
	GameStateHandler game_state_handler;
	ConfigMap* config_map;
	
	Session* active_session;
	StaticArray!(Server, 32) servers;

	this(Tid net_tid, GameStateHandler state_han, ConfigMap* config, TurnManager tm) {
		this.network_thread = net_tid;
		this.game_state_handler = state_han;
		this.config_map = config;
		this.tm = tm;
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

	void process_actions() {

		ubyte[2048] buf; //FIXME deal with this artificial limitation
		auto stream = OutputStream(buf.ptr, buf.length);
		foreach (action; tm.pending_actions) {

			auto type = UpdateType.ACTION;
			stream.write(type);

			auto id = action.identifier();
			stream.write(id);
			action.serialize(stream);

		}
	
		if (stream.current > 0) {
			send(network_thread, Command.UPDATE, cast(immutable(ubyte[]))stream[].idup);
		}

		tm.do_pending_actions(em);

	}

	void handle_messages() {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {

			writefln("[GAME] Recieved %s from net thread.", to!string(cmd));

			auto active_game_state = game_state_handler.peek();
			switch (cmd) with (Command) {

				case CREATE:
					//notify active game state
					active_session = new Session(this);
					active_game_state.on_command(cmd);
					break;

				case SET_CONNECTED:

					//send player data
					ubyte[4096] buf; //FIXME deal with this artificial limitation
					auto stream = OutputStream(buf.ptr, buf.length);

					auto type = UpdateType.PLAYER_DATA;
					stream.write(type);

					import std.algorithm : min;
					auto name = config_map.get("username");
					char[64] username;
					username[0..min(name.length, 64)] = name[0..min(name.length, 64)];
					auto data = PlayerData(cast(ubyte)name.length, username);
					stream.write(data);

					send_message(Command.UPDATE, cast(immutable(ubyte[]))stream[].idup);

					active_game_state.on_command(cmd);
					break;

				case DISCONNECT:
					active_game_state.on_command(cmd);
					break;

				default:
					writefln("[GAME] Unhandled message from net thread: %s", to!string(cmd));

			}

		},
		(Command cmd, ClientID id) {

			if (cmd == Command.ASSIGN_ID) {
				writefln("[GAME] Recieved id assignment: %d from net thread.", id);
				this.client_id = id;
			} else if (cmd == Command.NOTIFY_CONNECTION) {
				writefln("[GAME] Client %d connected. ", id);
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

					case UpdateType.PLAYER_DATA:
						PlayerData player = input_stream.read!PlayerData();
						writefln("[GAME] Handling player data - username: %s", 
								 player.player_name[0..player.length]);
						active_session.connections ~= Connection(StaticArray!(char, 64)(player.player_name[0..player.length]));
						break;

					case UpdateType.ACTION:

						ActionType action_type = input_stream.read!(ActionType)();

						switch (action_type) {

							mixin(handle_action());

							default:
								writefln("[GAME] Unhandled action type: %s", to!string(action_type));

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
		send(network_thread, data.idup); //FIXME this allocates, aaaargh?!

	}

	@property Connection[] connected_players() {
		assert(active_session !is null);
		return active_session.connected_players();
	}

	@property Session* current_session() {
		return active_session;
	}

	Server[] query_servers() {
		return servers[];
	}

} //GameNetworkManager

struct Session {

	GameNetworkManager nm;
	StaticArray!(Connection, 256) connections;

	this(GameNetworkManager nm) {
		this.nm = nm;
	}

	@property Connection[] connected_players() {
		return connections[];
	}

} //Session
