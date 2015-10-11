module blindfire.netgame;

import std.datetime : dur;

import blindfire.engine.stream : InputStream, OutputStream;
import blindfire.engine.state : GameState, GameStateHandler;
import blindfire.engine.event;
import blindfire.engine.log;
import blindfire.engine.net;
import blindfire.engine.ecs;

import blindfire.defs;
import blindfire.action;
import blindfire.config;

struct PlayerData {

	ubyte length;
	char[64] player_name;

} //PlayerData


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
} //Connection

struct ClientFSM {

	import blindfire.engine.fsm : FSM, FStateID, FStateTuple;

	alias UpdateFunc = void delegate();

	enum State : FStateID {
		Active,
		Waiting
	}

	@disable this();
	@disable this(this);

	mixin FSM!([State.Active, State.Waiting], //states
			   [FStateTuple(State.Active, State.Waiting), //transitions
			   FStateTuple(State.Waiting, State.Active)],
			   UpdateFunc);

	this(int v) {

		setInitialState(State.Waiting)
			.attachFunction(State.Active, &onActiveEnter, &onActiveExecute, &onActiveLeave)
			.attachFunction(State.Waiting, &onWaitingEnter, &onWaitingExecute, &onWaitingLeave);

	} //this

	~this() {

	} //~this

	void onActiveEnter(FStateID from) {

	} //onActiveEnter

	void onActiveExecute() {

	} //onActiveExecute

	void onActiveLeave(FStateID target) {

	} //onActiveLeave

	void onWaitingEnter(FStateID from) {

	} //onWaitingEnter

	void onWaitingExecute() {

	} //onWaitingExecute

	void onWaitingLeave(FStateID target) {

	} //onWaitingLeave

} //ClientFSM

class GameNetworkManager {

	import blindfire.engine.defs;

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

	public {

		float turn_length = 0.2f;
		float tick_length = 0.05f;
		uint ticks_per_second = 20;
		uint ticks_per_turn = 4;

		TurnID turn_id;
		TurnManager tm;
		EntityManager em;
		EventManager* network_client;

		ClientID client_id;

	}

	private {

		EventManager* evman;
		GameStateHandler game_state_handler;
		ConfigMap* config_map;

		Session* active_session;
		StaticArray!(Server, 32) servers;

	}

	this(EventManager* net_ev_man, GameStateHandler state_han, ConfigMap* config, TurnManager tm, EventManager* eventman) {
		this.network_client = net_ev_man;
		this.game_state_handler = state_han;
		this.config_map = config;
		this.tm = tm;
		this.evman = eventman;

		evman.register!ClientConnectEvent(&onClientConnect);
		evman.register!ClientDisconnectEvent(&onClientDisconnect);
		evman.register!StartGameEvent(&onCreateGame);

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
		auto stream = OutputStream(buf);
		foreach (action; tm.pending_actions) {

			auto type = UpdateType.ACTION;
			stream.write(type);

			auto id = action.identifier();
			stream.write(id);
			action.serialize(stream);

		}
	
		if (stream.current > 0) {
			network_client.push!GameUpdateEvent(stream[].idup);
		}

		tm.do_pending_actions(em);

	}

	void onCreateGameEvent(ref CreateGameEvent ev) {

		//notify active game state
		active_session = new Session(this);
		evman.push!GameCreatedEvent(true);

	} //onCreateGameEvent

	void onAssignIDEvent(ref AssignIDEvent ev) {

		auto id = ev.payload;
		writefln("[GAME] Recieved id assignment: %d from net thread.", id);
		this.client_id = id;

	} //onAssignIDEvent

	void onConnectionNotification(ref ConnectionNotificationEvent ev) {

		writefln("[GAME] Client %d connected.", ev.payload);

	} //onConnectionNotification

	void onGameUpdate(ref GameUpdateEvent ev) {

		import blindfire.serialize : deserialize;

		bool done = false;
		auto data = ev.payload;
		auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

		writefln("[GAME] Received packet, %d bytes", data.length);

		UpdateType type = input_stream.read!UpdateType();
		while (!done && input_stream.current < data.length) {

			switch (type) {

				case UpdateType.PLAYER_DATA: {

					PlayerData player = input_stream.read!PlayerData();
					writefln("[GAME] Handling player data - username: %s", 
							 player.player_name[0..player.length]);
					active_session.connections ~= Connection(StaticArray!(char, 64)(player.player_name[0..player.length]));

					break;

				}

				case UpdateType.ACTION: {

					import blindfire.action : handle_action;
					ActionType action_type = input_stream.read!(ActionType)();

					switch (action_type) {
						mixin(handle_action()); //generates code for handling each action type
						default:
							writefln("[GAME] Unhandled action type: %s", to!string(action_type));
					}

					break;

				}

				default: {
					writefln("[GAME] Unhandled Update Type: %s", to!string(type));
					done = true; //halt, or would get stuck in a loop.
				}

			}

		}

	} //onGameUpdate

	void onSetConnectionStatus(ref SetConnectionStatusEvent ev) {

		//send player data
		ubyte[4096] buf; //FIXME deal with this artificial limitation
		auto stream = OutputStream(buf);

		auto type = UpdateType.PLAYER_DATA;
		stream.write(type);

		import std.algorithm : min;
		auto name = config_map.get("username");
		char[64] username;
		username[0..min(name.length, 64)] = name[0..min(name.length, 64)];
		auto data = PlayerData(cast(ubyte)name.length, username);
		stream.write(data);

		send_message(stream[]);
		evman.push!ClientSetConnectedEvent(true);

	} //onSetConnectionStatus

	void onDisconnectedEvent(ref DisconnectedEvent ev) {
		evman.push!ClientDisconnectEvent(true);
	} //onDisconnectedEvent

	void onCreateGame(ref StartGameEvent ev) {
		network_client.push!CreateGameEvent(true);
	} //onCreateGame

	void onClientConnect(ref ClientConnectEvent ev) {
		network_client.push!DoConnectEvent(true);
	} //onClientConnect

	void onClientDisconnect(ref ClientDisconnectEvent ev) {
		network_client.push!DoDisconnectEvent(true);
	} //onClientDisconnect

	void send_action(T, Args...)(Args args) {
		tm.create_action!(T)(args);
	}

	void send_message(in ubyte[] data) {
		//copy data, send.
		network_client.push!GameUpdateEvent(data.idup);
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
