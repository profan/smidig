module blindfire.game;

import std.stdio : writefln;

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

	@property StateID id() const { return State.Menu; }
	
	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, EventManager* eventman) {

		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;

	} //this
	
	void enter() {

	} //enter

	void leave() {

	} //leave

	void update(double dt) {
	
	} //update

	void draw(Window* window) {

		uint width = 512, height = window.height - window.height/3;
		ui_state.draw_rectangle(window, 0, 0, window.width, window.height, BG_COLOR);
		ui_state.draw_rectangle(window, window.width/2-width/2, window.height/2-height/2, width, height, MENU_COLOR);

		ui_state.draw_label(window, "Project Blindfire", window.width/2, window.height/4, 0, 0, BG_COLOR);

		uint item_width = height / 2, item_height = 32;
		if (do_button(ui_state, 1, window, window.width/2, window.height/2 - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Join Game", MENU_COLOR)) {
			statehan.push_state(State.Joining);
		} //join

		if (do_button(ui_state, 2, window, window.width/2, window.height/2 + item_height/2*2, item_width, item_height, ITEM_COLOR, 255, "Create Game", MENU_COLOR)) {
			evman.push!CreateGameEvent(true);
			statehan.push_state(State.Lobby);
		} //create

		if (do_button(ui_state, 12, window, window.width/2, window.height/2 + item_height/2*5, item_width, item_height, ITEM_COLOR, 255, "Options", MENU_COLOR)) {
			statehan.push_state(State.Options);
		} //create

		if (do_button(ui_state, 3, window, window.width/2, window.height/2 + (item_height/2)*8, item_width, item_height, ITEM_COLOR, 255, "Quit Game", MENU_COLOR)) {
			window.is_alive = false;
		} //quit
			
	} //draw

} //MenuState

final class JoiningState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	GameNetworkManager netman;
	EventManager* evman;

	@property StateID id() const { return State.Joining; }

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
		this.netman = net;
	} //this

	void enter() {

		evman.register!ClientSetConnectedEvent(&onClientSetConnected);
		InternetAddress addr = new InternetAddress("localhost", 12000);
		evman.push!ClientConnectEvent(addr);

	} //enter

	void leave() {
		evman.unregister!ClientSetConnectedEvent(&onClientSetConnected);
	} //leave

	void onClientSetConnected(ref ClientSetConnectedEvent ev) {
		statehan.switch_state(State.Lobby);
	} //onClientSetConnected

	void update(double dt) {

	} //update

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

	} //draw

} //JoiningState


// state handles match-preparation stage (whatever that may be?)
final class LobbyState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	GameNetworkManager netman;
	EventManager* evman;

	@property StateID id() const { return State.Lobby; }

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
		this.netman = net;
	} //this

	void enter() {
		evman.register!ClientSetConnectedEvent(&onClientSetConnected);
	} //enter

	void leave() {
		evman.unregister!ClientSetConnectedEvent(&onClientSetConnected);
	} //leave

	void onClientSetConnected(ref ClientSetConnectedEvent ev) {
		statehan.switch_state(State.Game);
	} //onClientSetConnected

	void update(double dt) {

	} //update

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
			statehan.switch_state(State.Game);
		}

		if (do_button(ui_state, 9, window, item_width + item_width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Quit Game", 0x428bca)) {
			evman.push!ClientDisconnectEvent(true);
			statehan.pop_state();
		} //back to menu

	} //draw

} //LobbyState

final class MatchState : GameState {

	import blindfire.engine.ecs : EntityID, EntityManager;
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

	@property StateID id() const { return State.Game; }

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man, Console* console, FontAtlas* atlas, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;
		this.evman = eventman;

		this.console = console;
		this.debug_atlas = atlas;

		this.entity_allocator = LinearAllocator(1024 * 32, "EntityAllocator"); //32 megabytes :D

		import blindfire.engine.memory : theAllocator;

		alias ea = entity_allocator;
		this.em = ea.alloc!(EntityManager)(theAllocator);
		this.em.addSystem(ea.alloc!(TransformManager)());
		this.em.addSystem(ea.alloc!(CollisionManager)(Vec2i(640, 480)));
		this.em.addSystem(ea.alloc!(SpriteManager)());
		this.em.addSystem(ea.alloc!(InputManager)());
		this.em.addSystem(ea.alloc!(OrderManager)(&sbox, net_man.tm));
		this.em.addSystem(ea.alloc!(SelectionManager)());

		this.sbox = SelectionBox();

		//where do these bindings actually belong? WHO KNOWS
		evhan.bind_mousebtn(1, &sbox.set_active, KeyState.DOWN);
		evhan.bind_mousebtn(1, &sbox.set_inactive, KeyState.UP);
		evhan.bind_mousebtn(3, &sbox.set_order, KeyState.UP);
		evhan.bind_mousemov(&sbox.set_size);

		net_man.em = em;

	} //this

	void enter() {
		evman.register!ClientDisconnectEvent(&onClientDisconnect);
	} //enter

	void leave() {

		//remove all things
		evman.unregister!ClientDisconnectEvent(&onClientDisconnect);
		em.clearSystems();

	} //leave

	void onClientDisconnect(ref ClientDisconnectEvent ev) {
		statehan.pop_state();
	} //onClientDisconnect

	void update(double dt) {

		em.tick!(UpdateSystem)();

	} //update

	void draw_debug(Window* window) {

		auto offset = Vec2i(16, 144);

		float allocated_percent = cast(float)entity_allocator.allocated_size / entity_allocator.total_size;
		debug_atlas.render_string!("entity allocator - alllocated: %f %%")(window, offset, allocated_percent);

	} //draw_debug

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

	} //draw

} //MatchState

//when waiting for another player to connect?
final class WaitingState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	EventManager* evman;

	@property StateID id() const { return State.Waiting; }

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, EventManager* eventman) {
		this.statehan = statehan;
		this.ui_state = state;
		this.evman = eventman;
	} //this

	void enter() {

	} //enter

	void leave() {
	
	} //leave

	void update(double dt) {

	} //update

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

	@property StateID id() const { return State.Options; }

	this(GameStateHandler state_handler, EventHandler* event_handler, UIState* ui, ConfigMap* conf, EventManager* eventman) {
		this.statehan = state_handler;
		this.evhan = event_handler;
		this.ui_state = ui;
		this.config_map = conf;
		this.evman = eventman;
	} //this

	void enter() {
		player_name ~= config_map.get("username");
	} //enter

	void leave() {
		player_name.length = 0;
	} //leave

	void update(double dt) {

	} //update

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
	} //draw

} //OptionsState

struct Game {

	import blindfire.res : Resource;
	import blindfire.engine.sound : SoundSystem, SoundID;

	private {

		Window* window;
		EventManager net_evman;
		NetworkPeer network_client;
		SoundSystem* sound_system;

		EventManager evman;
		EventHandler* evhan;
		GameStateHandler state;
		UIState ui_state;

		GameNetworkManager net_man;
		ConfigMap config_map;
		TurnManager tm;

		LinearAllocator master_allocator;
		LinearAllocator* resource_allocator;
		LinearAllocator* system_allocator;

		Console* console;
		Cursor* cursor;

		//timekeeping
		TickDuration iter, last;
		float frametime, updatetime, drawtime;
		FontAtlas* debug_atlas;

	}

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.net_evman = EventManager(EventMemory, NetEventType.max);
		this.network_client = NetworkPeer(12000, &net_evman);

		this.master_allocator = LinearAllocator(65536, "MasterAllocator");
		this.resource_allocator = master_allocator.alloc!(LinearAllocator)(16384, "ResourceAllocator", &master_allocator);
		this.system_allocator = master_allocator.alloc!(LinearAllocator)(32768, "SystemAllocator", &master_allocator);

		this.evman = EventManager(EventMemory, EventType.max);
		this.evhan = evhan;
		this.ui_state = UIState();
		this.config_map = ConfigMap("game.cfg");
		
	} //this

	void update(double dt) {

		//wow
		state.update(dt);

	} //update

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

	} //draw_debug

	void draw() {

		//such draw
		ui_state.before_ui();
		state.draw(window);
		ui_state.reset_ui();
	
		draw_debug();
		cursor.draw(window.view_projection, Vec2f(evhan.last_x[0], evhan.last_y[0]));

	} //draw

	void load_resources() {

		import blindfire.engine.gl;

		alias ra = resource_allocator;
		auto rm = ResourceManager.get();

		//shaders
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = ra.alloc!(Shader)("shaders/basic", attributes[], uniforms[]);
		rm.set_resource(shader, Resource.BASIC_SHADER);

		AttribLocation[1] text_attribs = [AttribLocation(0, "coord")];
		char[16][2] text_uniforms = ["color", "projection"];
		auto text_shader = ra.alloc!(Shader)("shaders/text", text_attribs[], text_uniforms[]); 
		rm.set_resource(text_shader, Resource.TEXT_SHADER);

		//textures
		auto unit_tex = ra.alloc!(Texture)("resource/img/dude2.png");
		rm.set_resource(unit_tex, Resource.UNIT_TEXTURE);

		//font atlases and such
		this.debug_atlas = system_allocator.alloc!(FontAtlas)("fonts/OpenSans-Regular.ttf", 12, text_shader);
		this.console = system_allocator.alloc!(Console)(debug_atlas, &evman);

		//mouse pointer texture
		auto cursor_texture = ra.alloc!(Texture)("resource/img/other_cursor.png");
		rm.set_resource(cursor_texture, Resource.CURSOR_TEXTURE);
		this.cursor = system_allocator.alloc!(Cursor)(cursor_texture, shader);
		SDL_ShowCursor(SDL_DISABLE); //make sure to disable default cursor

	} //load_resources

	void load_sounds() {

		auto rm = ResourceManager.get();
		auto music_file = sound_system.load_sound_file(cast(char*)"resource/audio/paniq.wav".ptr);
		rm.set_resource!(SoundID)(cast(SoundID*)music_file, Resource.PANIQ);

	} //load_sounds

	void initialize_systems() {

		this.network_client.initialize();

		//upload vertices for ui to gpu, set up shaders.
		this.ui_state.initialize(system_allocator);

		alias ra = system_allocator;
		this.sound_system = ra.alloc!(SoundSystem)(32);
		this.sound_system.initialize();

		this.state = ra.alloc!(GameStateHandler)();

		this.tm = ra.alloc!(TurnManager)();
		this.net_man = ra.alloc!(GameNetworkManager)(&net_evman, state, &config_map, tm, &evman);

		state.add_state(ra.alloc!(MenuState)(state, evhan, &ui_state, &evman));
		state.add_state(ra.alloc!(MatchState)(state, evhan, &ui_state, net_man, console, debug_atlas, &evman));
		state.add_state(ra.alloc!(JoiningState)(state, evhan, &ui_state, net_man, &evman));
		state.add_state(ra.alloc!(LobbyState)(state, evhan, &ui_state, net_man, &evman));
		state.add_state(ra.alloc!(WaitingState)(state, evhan, &ui_state, &evman));
		state.add_state(ra.alloc!(OptionsState)(state, evhan, &ui_state, &config_map, &evman));
		state.push_state(State.Menu); //set initial state

		evhan.add_listener(&ui_state.update_ui);
		evhan.bind_keyevent(SDL_SCANCODE_RALT, &window.toggle_wireframe);

		//bind keys and such
		evhan.add_listener(&console.handle_event);
		evhan.bind_keyevent(SDL_SCANCODE_TAB, &console.toggle);
		evhan.bind_keyevent(SDL_SCANCODE_BACKSPACE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_DELETE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_RETURN, &console.run);
		evhan.bind_keyevent(SDL_SCANCODE_DOWN, &console.get_prev);
		evhan.bind_keyevent(SDL_SCANCODE_UP, &console.get_next);

	} //initialize_systems

	void register_concommands() {

		import blindfire.engine.console : ConsoleCommand;

		console.bind_command(ConsoleCommand.SET_TICKRATE,
			(Console* console, in char[] args) {
				int tickrate = to!int(args);
				auto new_iter = TickDuration.from!("msecs")(1000/tickrate);
				console.evman.push!SetTickrateEvent(new_iter);
		});

		console.bind_command(ConsoleCommand.PUSH_STATE,
			(Console* console, in char[] args) {
				int new_state = to!int(args);
				if (new_state >= State.min && new_state <= State.max) {
					console.evman.push!PushGameStateEvent(cast(State)new_state);
				}
		});

		evman.register!SetTickrateEvent(&onSetTickrate);
		evman.register!PushGameStateEvent(&onGameStatePush);

	} //register_concommands

	void onSetTickrate(ref SetTickrateEvent ev) {
		this.iter = ev.payload;
	} //onSetTickrate

	void onGameStatePush(ref PushGameStateEvent ev) {
		this.state.push_state(ev.payload);
	} //onGameStatePush

	void run() {

		import core.thread : Thread;
		import std.datetime : Duration, StopWatch, TickDuration;

		//load game resources
		load_resources();

		//allocate resources for systems
		initialize_systems();

		//load sounds
		load_sounds();

		auto retrieved_sound = ResourceManager.get().get_resource!(SoundID)(Resource.PANIQ);
		sound_system.play_sound(cast(SoundID)retrieved_sound, 0.25f);

		//terminate network worker when run goes out of scope, because the game has ended
		//scope(exit) { net_man.send_message(Command.TERMINATE); } TODO REVISIT

		//register console commands
		register_concommands();

		StopWatch sw;
		this.iter = TickDuration.from!("msecs")(16);
		this.last = TickDuration.from!("msecs")(0);

		StopWatch ft_sw, ut_sw, dt_sw;
		ft_sw.start();
		ut_sw.start();
		dt_sw.start();

		sw.start();
		auto start_time = sw.peek();
		while(window.is_alive) {

			ft_sw.start();

			if (sw.peek() - last > iter) {

				mixin EventManager.doTick!();

				ut_sw.start();
				tick!EventIdentifier(evman);
				tick!NetEventIdentifier(net_evman);

				evhan.handle_events();
				network_client.tick();
				net_man.process_actions();
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

	} //run

} //Game

struct NewGame {

	import blindfire.engine.runtime;

	private {

		Engine engine_;

	}

	@disable this();
	@disable this(this);

	void initialize() {

		this.engine_.initialize("Project Blindfire");

	} //initialize

	void initialize_systems() {

	} //initialize_systems

	void load_resources() {
	
	} //load_resources

	void run() {

	} //run

} //NewGame
