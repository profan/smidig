module blindfire.game;

import std.stdio : writefln;
import std.concurrency : spawn, thisTid;

import derelict.sdl2.sdl;

import blindfire.engine.window;
import blindfire.engine.eventhandler;
import blindfire.engine.console : Console;
import blindfire.engine.text : FontAtlas;
import blindfire.engine.util : render_string;
import blindfire.engine.memory : LinearAllocator;
import blindfire.engine.resource;
import blindfire.engine.state;
import blindfire.engine.event;
import blindfire.engine.defs;
import blindfire.engine.net;
import blindfire.engine.gl;

import blindfire.graphics;
import blindfire.netgame;
import blindfire.config;
import blindfire.defs;
import blindfire.ui;

const int BG_COLOR = 0xca8142;
const int MENU_COLOR = 0x428bca;
const int ITEM_COLOR = 0x8bca42;

final class MenuState : GameState {
	
	UIState* ui_state;
	GameStateHandler statehan;
	EventManager* evman;
	
	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, EventManager* eventman) {

		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;

	}
	
	void enter() {

	}

	void leave() {

	}

	void update(double dt) {
	
	}

	void draw(Window* window) {

		uint width = 512, height = window.height - window.height/3;
		ui_state.draw_rectangle(window, 0, 0, window.width, window.height, BG_COLOR);
		ui_state.draw_rectangle(window, window.width/2-width/2, window.height/2-height/2, width, height, MENU_COLOR);

		ui_state.draw_label(window, "Project Blindfire", window.width/2, window.height/4, 0, 0, BG_COLOR);

		uint item_width = height / 2, item_height = 32;
		if (do_button(ui_state, 1, window, window.width/2, window.height/2 - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Join Game", MENU_COLOR)) {
			statehan.push_state(State.JOIN);
		} //join

		if (do_button(ui_state, 2, window, window.width/2, window.height/2 + item_height/2*2, item_width, item_height, ITEM_COLOR, 255, "Create Game", MENU_COLOR)) {
			evman.push!CreateGameEvent(true);
			statehan.push_state(State.LOBBY);
		} //create

		if (do_button(ui_state, 12, window, window.width/2, window.height/2 + item_height/2*5, item_width, item_height, ITEM_COLOR, 255, "Options", MENU_COLOR)) {
			statehan.push_state(State.OPTIONS);
		} //create

		if (do_button(ui_state, 3, window, window.width/2, window.height/2 + (item_height/2)*8, item_width, item_height, ITEM_COLOR, 255, "Quit Game", MENU_COLOR)) {
			window.is_alive = false;
		} //quit
			
	}

} //MenuState

final class JoiningState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	GameNetworkManager netman;
	EventManager* evman;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
		this.netman = net;
	}

	void enter() {
		evman.register!ClientSetConnectedEvent(&onClientSetConnected);
		InternetAddress addr = new InternetAddress("localhost", 12000);
		evman.push!ClientConnectEvent(addr);
	}

	void leave() {
		evman.unregister!ClientSetConnectedEvent(&onClientSetConnected);
	}

	void onClientSetConnected(EventCast* ev) {
		auto cev = ev.extract!ClientSetConnectedEvent();
		statehan.pop_state();
		statehan.push_state(State.LOBBY);
	}

	void update(double dt) {

	}

	void draw(Window* window) {

		uint item_width = window.width/2, item_height = 32;
		if (do_button(ui_state, 4, window, window.width/2, window.height/2 - item_height, item_width, item_height, ITEM_COLOR)) {
			evman.push!ClientDisconnectEvent(true);
			statehan.pop_state();
		} //back to menu, cancel


		auto offset = Vec2i(0, 0);
		ui_state.draw_label(window, "Local Servers", offset.x, offset.y, 0, 0, 0x428bca);
		offset.x += item_height * 2;

		auto servers = netman.query_servers();
		foreach (server; servers) {
			ui_state.draw_label(window, server.server_name[], offset.x, offset.y, 0, 0, 0x428bca);
			offset.x += item_height;
		}

	}

} //JoiningState


// state handles match-preparation stage (whatever that may be?)
final class LobbyState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	GameNetworkManager netman;
	EventManager* evman;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
		this.netman = net;
	}

	void enter() {
		evman.register!ClientSetConnectedEvent(&onClientSetConnected);
	}

	void leave() {
		evman.unregister!ClientSetConnectedEvent(&onClientSetConnected);
	}

	void onClientSetConnected(EventCast* ev) {
		auto cev = ev.extract!ClientSetConnectedEvent();
		statehan.pop_state();
		statehan.push_state(State.GAME);
	}

	void update(double dt) {

	}

	void draw(Window* window) {

		uint item_width = window.width / 2, item_height = 32;
		ui_state.draw_rectangle(window, 0, 0, window.width, window.height, BG_COLOR);

		uint offset_x = window.width/3, offset_y = window.height/3;

		ui_state.draw_label(window, "Players", offset_x, offset_y, 0, 0, 0x428bca);
		offset_y += item_height * 2;

		//list players here
		/*foreach(player; netman.connected_players) {
			ui_state.draw_label(window, player.player_name[], offset_x, offset_y, 0, 0, 0x428bca);
			offset_y += item_height;
		}*/

		//bottom left for quit button
		if (do_button(ui_state, 8, window, item_width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Start Game", 0x428bca)) {
			evman.push!ClientSetConnectedEvent(true);
			statehan.pop_state();
			statehan.push_state(State.GAME);
		}

		if (do_button(ui_state, 9, window, item_width + item_width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Quit Game", 0x428bca)) {
			evman.push!ClientDisconnectEvent(true);
			statehan.pop_state();
		} //back to menu

	}

} //LobbyState

final class MatchState : GameState {

	import profan.ecs : EntityID, EntityManager;
	import blindfire.action : SelectionBox;
	import blindfire.ents : create_unit;
	import blindfire.sys;

	GameStateHandler statehan;
	GameNetworkManager net_man;
	UIState* ui_state;

	SelectionBox sbox;
	EntityManager em;
	EventManager* evman;

	Console* console;
	FontAtlas* debug_atlas;

	LinearAllocator entity_allocator;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man, Console* console, FontAtlas* atlas, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;
		this.evman = eventman;

		this.console = console;
		this.debug_atlas = atlas;

		this.entity_allocator = LinearAllocator(1024 * 32, "EntityAllocator"); //32 megabytes :D

		alias ea = entity_allocator;
		this.em = ea.alloc!(EntityManager)();
		this.em.add_system(ea.alloc!(TransformManager)());
		this.em.add_system(ea.alloc!(CollisionManager)(Vec2i(640, 480)));
		this.em.add_system(ea.alloc!(SpriteManager)());
		this.em.add_system(ea.alloc!(InputManager)());
		this.em.add_system(ea.alloc!(OrderManager)(&sbox, net_man.tm));
		this.em.add_system(ea.alloc!(SelectionManager)());

		this.sbox = SelectionBox();

		//where do these bindings actually belong? WHO KNOWS
		evhan.bind_mousebtn(1, &sbox.set_active, KeyState.DOWN);
		evhan.bind_mousebtn(1, &sbox.set_inactive, KeyState.UP);
		evhan.bind_mousebtn(3, &sbox.set_order, KeyState.UP);
		evhan.bind_mousemov(&sbox.set_size);

		net_man.em = em;

	}

	void enter() {
		evman.register!ClientDisconnectEvent(&onClientDisconnect);
	}

	void leave() {

		//remove all things
		evman.unregister!ClientDisconnectEvent(&onClientDisconnect);
		em.clear_systems();

	}

	void onClientDisconnect(EventCast* ev) {
		auto cdev = ev.extract!ClientDisconnectEvent();
		statehan.pop_state();
	}

	void update(double dt) {

		em.tick!(UpdateSystem)();

	}

	void draw_debug(Window* window) {

		auto offset = Vec2i(16, 144);

		float allocated_percent = cast(float)entity_allocator.allocated_size / entity_allocator.total_size;
		debug_atlas.render_string!("entity allocator - alllocated: %f %%")(window, offset, allocated_percent);

	}

	void draw(Window* window) {

		em.tick!(DrawSystem)(window);
		sbox.draw(window, ui_state);

		uint item_width = window.width / 2, item_height = 32;
		if (do_button(ui_state, 5, window, window.width/2, window.height - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Quit", 0x428bca)) {
			evman.push!ClientDisconnectEvent(true);
			statehan.pop_state();
		} //back to menu

		if (do_button(ui_state, 6, window, window.width/2, window.height - cast(int)(item_height*1.5), item_width, item_height, ITEM_COLOR, 255, "Create Units", 0x428bca)) {
			
			import std.random : uniform;
			import blindfire.action : CreateUnitAction;

			for (uint i = 0; i < 10; ++i) {
				int n_x = uniform(0, 640);
				int n_y = uniform(0, 480);
				net_man.send_action!(CreateUnitAction)(Vec2f(n_x, n_y));
			}

		}

		draw_debug(window);

	}

} //MatchState

//when waiting for another player to connect?
final class WaitingState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	EventManager* evman;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
	}

	void enter() {

	}

	void leave() {
	
	}

	void update(double dt) {

	}

	void draw(Window* window) {

		uint item_width = window.width / 2, item_height = 32;
		if (do_button(ui_state, 6, window, window.width/2, window.height - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Cancel", 0x428bca)) {
			evman.push!ClientDisconnectEvent();
			statehan.pop_state();
		} //back to menu

	}

} //WaitingState

final class OptionsState : GameState {

	GameStateHandler statehan;
	EventManager* evman;
	EventHandler* evhan;
	UIState* ui_state;

	ConfigMap* config_map;

	//options
	StaticArray!(char, 64) player_name;

	this(GameStateHandler state_handler, EventHandler* event_handler, UIState* ui, ConfigMap* conf, EventManager* eventman) {
		this.statehan = state_handler;
		this.evhan = event_handler;
		this.ui_state = ui;
		this.config_map = conf;
		this.evman = eventman;
	}

	void enter() {
		player_name ~= config_map.get("username");
	}

	void leave() {
		player_name.length = 0;
	}

	void update(double dt) {

	}

	void draw(Window* window) {

		uint item_width = window.width / 2, item_height = 32;
		ui_state.draw_rectangle(window, 0, 0, window.width, window.height, BG_COLOR);
		ui_state.draw_label(window, "Player Name", window.width/2, window.height/4, 0, 0, 0x428bca);
		ui_state.do_textbox(13, window, window.width/2, window.height/4+item_height, item_width, item_height, player_name, darken(BG_COLOR, 10), darken(0x428bca, 25));

		if (do_button(ui_state, 14, window, window.width/2, window.height/4+cast(int)(item_height*2.5), item_width, item_height, ITEM_COLOR, 255, "Save", 0x428bca)) {
			config_map.set("username", player_name[]);
			config_map.save_file();
		} //save options

		if (do_button(ui_state, 12, window, window.width/2, window.height - item_height/2, item_width, item_height, ITEM_COLOR, 255, "To Menu", 0x428bca)) {
			statehan.pop_state();
		} //back to menu
	}

} //OptionsState

enum Resource : ResourceID {

	//shaders
	BASIC_SHADER,
	TEXT_SHADER,

	//textures

	//cursor
	CURSOR_TEXTURE,

	//units
	UNIT_TEXTURE

}

struct Game {

	Window* window;
	EventManager evman;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;

	Tid network_thread;
	GameNetworkManager net_man;
	ConfigMap config_map;
	TurnManager tm;

	LinearAllocator master_allocator;
	LinearAllocator* resource_allocator;
	LinearAllocator* system_allocator;

	float frametime, updatetime, drawtime;
	FontAtlas* debug_atlas;
	Console* console;
	Cursor* cursor;

	//timekeeping
	TickDuration iter, last;

	this(Window* window, EventHandler* evhan) {

		this.master_allocator = LinearAllocator(65536, "MasterAllocator");
		this.resource_allocator = master_allocator.alloc!(LinearAllocator)(16384, "ResourceAllocator", &master_allocator);
		this.system_allocator = master_allocator.alloc!(LinearAllocator)(32768, "SystemAllocator", &master_allocator);

		this.evman = EventManager(EventMemory);
		this.evhan = evhan;
		this.window = window;
		this.ui_state = UIState();
		this.config_map = ConfigMap("game.cfg");
		
	}

	void update(double dt) {

		//wow
		state.update(dt);

	}

	void draw_debug() {

		console.draw(window);

		auto offset = Vec2i(16, 32);
		debug_atlas.render_string!("frametime: %f ms")(window, offset, frametime);
		debug_atlas.render_string!("update: %f ms")(window, offset, updatetime);
		debug_atlas.render_string!("draw: %f ms")(window, offset, drawtime);
		debug_atlas.render_string!("client id: %d")(window, offset, net_man.client_id);
		debug_atlas.render_string!("turn id: %d")(window, offset, net_man.turn_id);
		debug_atlas.render_string!("bytes in/sec: %f")(window, offset,
				blindfire.engine.net.network_stats.bytes_in_per_second);
		debug_atlas.render_string!("bytes out/sec: %f")(window, offset,
				blindfire.engine.net.network_stats.bytes_out_per_second);

	}

	void draw() {

		//such draw
		ui_state.before_ui();
		state.draw(window);
		ui_state.reset_ui();
	
		draw_debug();
		cursor.draw(window.view_projection, Vec2f(evhan.last_x[0], evhan.last_y[0]));

	}

	void load_resources() {

		import blindfire.engine.gl;

		alias ra = resource_allocator;
		auto rm = ResourceManager.get();

		//shaders
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = ra.alloc!(Shader)("shaders/basic", attributes[], uniforms[]);
		rm.set_resource!(Shader)(shader, Resource.BASIC_SHADER);

		AttribLocation[1] text_attribs = [AttribLocation(0, "coord")];
		char[16][2] text_uniforms = ["color", "projection"];
		auto text_shader = ra.alloc!(Shader)("shaders/text", text_attribs[], text_uniforms[]); 
		rm.set_resource!(Shader)(text_shader, Resource.TEXT_SHADER);

		//textures
		auto unit_tex = ra.alloc!(Texture)("resource/img/dude2.png");
		rm.set_resource!(Texture)(unit_tex, Resource.UNIT_TEXTURE);

		//font atlases and such
		this.debug_atlas = system_allocator.alloc!(FontAtlas)("fonts/OpenSans-Regular.ttf", 12, text_shader);
		this.console = system_allocator.alloc!(Console)(debug_atlas, &evman);

		auto cursor_texture = ra.alloc!(Texture)("resource/img/other_cursor.png");
		rm.set_resource!(Texture)(cursor_texture, Resource.CURSOR_TEXTURE);
		this.cursor = system_allocator.alloc!(Cursor)(cursor_texture, shader);
		SDL_ShowCursor(SDL_DISABLE);

	}

	struct Thing {
		this (int v) {
			this.var = v;
		}
		int var;
	}

	void onSetTickrate(EventCast* ev) {
		auto sev = ev.extract!SetTickrateEvent();
		this.iter = sev.payload;
	}

	void onGameStatePush(EventCast* ev) {
		auto gev = ev.extract!PushGameStateEvent();
		this.state.push_state(gev.payload);
	}

	void run() {

		import std.datetime : Duration, StopWatch, TickDuration;
		import blindfire.engine.memory : FreeListAllocator;

		auto fa = FreeListAllocator(1024, "SomeFreeList");
		auto ptr_to_thing1 = fa.alloc!(Thing)(210);
		printf("thing1: %d", ptr_to_thing1.var);

		auto ptr_to_thing2 = fa.alloc!(Thing)(420);
		printf("thing2: %d", ptr_to_thing2.var);

		fa.dealloc(ptr_to_thing1);
		fa.dealloc(ptr_to_thing2);

		//load game resources
		load_resources();

		//upload vertices for ui to gpu, set up shaders.
		ui_state.init(system_allocator);

		alias ra = system_allocator;
		state = ra.alloc!(GameStateHandler)();
		network_thread = spawn(&launch_peer, thisTid); //pass game thread so it can pass recieved messages back

		tm = ra.alloc!(TurnManager)();
		net_man = ra.alloc!(GameNetworkManager)(network_thread, state, &config_map, tm, &evman);
		scope(exit) { net_man.send_message(Command.TERMINATE); } //terminate network worker when run goes out of scope, because the game has ended

		state.add_state(ra.alloc!(MenuState)(state, evhan, &ui_state, &evman), State.MENU);
		state.add_state(ra.alloc!(MatchState)(state, evhan, &ui_state, net_man, console, debug_atlas, &evman), State.GAME);
		state.add_state(ra.alloc!(JoiningState)(state, evhan, &ui_state, net_man, &evman), State.JOIN);
		state.add_state(ra.alloc!(LobbyState)(state, evhan, &ui_state, net_man, &evman), State.LOBBY);
		state.add_state(ra.alloc!(WaitingState)(state, evhan, &ui_state, &evman), State.WAIT);
		state.add_state(ra.alloc!(OptionsState)(state, evhan, &ui_state, &config_map, &evman), State.OPTIONS);
		state.push_state(State.MENU);

		evhan.add_listener(&ui_state.update_ui);
		evhan.bind_keyevent(SDL_SCANCODE_RALT, &window.toggle_wireframe);

		evhan.add_listener(&console.handle_event);
		evhan.bind_keyevent(SDL_SCANCODE_TAB, &console.toggle);
		evhan.bind_keyevent(SDL_SCANCODE_BACKSPACE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_DELETE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_RETURN, &console.run);
		evhan.bind_keyevent(SDL_SCANCODE_DOWN, &console.get_prev);
		evhan.bind_keyevent(SDL_SCANCODE_UP, &console.get_next);

		import core.thread : Thread;
		
		StopWatch sw;
		iter = TickDuration.from!("msecs")(16);
		last = TickDuration.from!("msecs")(0);

		import blindfire.defs : SetTickrateEvent;
		import blindfire.engine.console : ConsoleCommand;
		console.bind_command(ConsoleCommand.SET_TICKRATE,
			(Console* console, in char[] args) {
				int tickrate = to!int(args);
				auto new_iter = TickDuration.from!("msecs")(1000/tickrate);
				console.evman.push!SetTickrateEvent(new_iter);
		});

		evman.register!SetTickrateEvent(&onSetTickrate);

		console.bind_command(ConsoleCommand.PUSH_STATE,
			(Console* console, in char[] args) {
				int new_state = to!int(args);
				if (new_state >= State.min && new_state <= State.max) {
					console.evman.push!PushGameStateEvent(cast(State)new_state);
				}
		});

		evman.register!PushGameStateEvent(&onGameStatePush);

		StopWatch ft_sw, ut_sw, dt_sw;
		ft_sw.start();
		ut_sw.start();
		dt_sw.start();

		sw.start();
		auto start_time = sw.peek();
		while(window.is_alive) {

			ft_sw.start();

			net_man.handle_messages();
			net_man.process_actions();

			if (sw.peek() - last > iter) {

				ut_sw.start();
				evman.tick();
				evhan.handle_events();
				update(1.0);
				last = sw.peek();
				updatetime = ut_sw.peek().msecs;
				ut_sw.reset();

			}

			dt_sw.start();
			window.render_clear(0x428bca);
			draw();
			window.render_present();
			drawtime = dt_sw.peek().msecs;
			frametime = ft_sw.peek().msecs;

			dt_sw.reset();
			ft_sw.reset();
			
			auto diff = cast(Duration)(last - sw.peek()) + iter;
			if (diff > dur!("hnsecs")(0)) {
				Thread.sleep(diff);
			}

		}

	}

} //Game
