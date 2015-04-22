module blindfire.game;

import std.stdio : writefln;
import std.concurrency : spawn, thisTid;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;
import derelict.freetype.ft;

import blindfire.engine.window;
import blindfire.engine.eventhandler;
import blindfire.engine.console : Console;
import blindfire.engine.text : FontAtlas;
import blindfire.engine.util : render_string;
import blindfire.engine.memory : LinearAllocator;
import blindfire.engine.resource;
import blindfire.engine.state;
import blindfire.engine.defs;
import blindfire.engine.net;
import blindfire.engine.gl;

import blindfire.graphics;
import blindfire.netgame;
import blindfire.config;
import blindfire.ui;

const int BG_COLOR = 0xca8142;
const int MENU_COLOR = 0x428bca;
const int ITEM_COLOR = 0x8bca42;

final class MenuState : GameState {
	
	UIState* ui_state;
	GameStateHandler statehan;

	GameNetworkManager net_man;
	
	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man) {

		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;

	}
	
	override void enter() {

	}

	override void leave() {

	}

	override void update(double dt) {
	
	}

	override void draw(Window* window) {

		uint width = 512, height = window.height - window.height/3;
		ui_state.draw_rectangle(window, 0, 0, window.width, window.height, BG_COLOR);
		ui_state.draw_rectangle(window, window.width/2-width/2, window.height/2-height/2, width, height, MENU_COLOR);

		ui_state.draw_label(window, "Project Blindfire", window.width/2, window.height/4, 0, 0, BG_COLOR);

		uint item_width = height / 2, item_height = 32;
		if (do_button(ui_state, 1, window, window.width/2, window.height/2 - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Join Game", MENU_COLOR)) {
			statehan.push_state(State.JOIN);
		} //join

		if (do_button(ui_state, 2, window, window.width/2, window.height/2 + item_height/2*2, item_width, item_height, ITEM_COLOR, 255, "Create Game", MENU_COLOR)) {
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
	GameNetworkManager net_man;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;

		net_man.on_connect ~= &on_connect;

	}

	override void enter() {
		InternetAddress addr = new InternetAddress("localhost", 12000);
		net_man.send_message(Command.CONNECT, cast(shared)addr);
	}

	override void leave() {

	}

	override void update(double dt) {

	}

	void on_connect() {

		statehan.pop_state();
		statehan.push_state(State.LOBBY);

	}

	override void draw(Window* window) {

		uint item_width = window.width/2, item_height = 32;
		if (do_button(ui_state, 4, window, window.width/2, window.height/2 - item_height, item_width, item_height, ITEM_COLOR)) {
			statehan.pop_state();
		} //back to menu, cancel

	}

} //JoiningState


// state handles match-preparation stage (whatever that may be?)
final class LobbyState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	GameNetworkManager net_man;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;
	}

	void enter() {

		net_man.send_message(Command.CREATE);

	}

	void leave() {

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
		

		//bottom left for quit button
		if (do_button(ui_state, 8, window, item_width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Start Game", 0x428bca)) {
			net_man.send_message(Command.CREATE);
			statehan.pop_state();
			statehan.push_state(State.GAME);
		}

		if (do_button(ui_state, 9, window, item_width + item_width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Quit Game", 0x428bca)) {
			net_man.send_message(Command.DISCONNECT);
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

	Console* console;
	FontAtlas* debug_atlas;

	LinearAllocator entity_allocator;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man, Console* console, FontAtlas* atlas) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;

		this.console = console;
		this.debug_atlas = atlas;

		this.entity_allocator = LinearAllocator(1024 * 1024 * 32); //32 megabytes :D

		alias ea = entity_allocator;
		this.em = ea.alloc!(EntityManager)();
		this.em.add_system(ea.alloc!(TransformManager)());
		this.em.add_system(ea.alloc!(CollisionManager)());
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

	override void enter() {

	}

	override void leave() {

		//remove all things
		em.clear_systems();

	}

	override void update(double dt) {

		em.tick!(UpdateSystem)();

	}

	void draw_debug(Window* window) {

		auto offset = Vec2i(16, 144);

		float allocated_percent = cast(float)entity_allocator.allocated_size / entity_allocator.total_size;
		debug_atlas.render_string!("entity allocator - alllocated: %f %%")(window, offset, allocated_percent);

	}

	override void draw(Window* window) {

		em.tick!(DrawSystem)(window);
		sbox.draw(window, ui_state);

		uint item_width = window.width / 2, item_height = 32;
		if (do_button(ui_state, 5, window, window.width/2, window.height - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Quit", 0x428bca)) {
			statehan.pop_state();
		} //back to menu

		if (do_button(ui_state, 6, window, window.width/2, window.height - item_height, item_width, item_height, ITEM_COLOR, 255, "Create Units", 0x428bca)) {
			
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
	GameNetworkManager net_man;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, GameNetworkManager net_man) {
		this.statehan = statehan;
		this.ui_state = state;
		this.net_man = net_man;
	}

	override void enter() {

	}

	override void leave() {
	
	}
	
	override void update(double dt) {

	}

	override void draw(Window* window) {

		uint item_width = window.width / 2, item_height = 32;
		if (do_button(ui_state, 6, window, window.width/2, window.height - item_height/2, item_width, item_height, ITEM_COLOR, 255, "Cancel", 0x428bca)) {
			net_man.send_message(Command.DISCONNECT);
			statehan.pop_state();
		} //back to menu

	}

} //WaitingState

class OptionsState : GameState {

	GameStateHandler statehan;
	EventHandler* evhan;
	UIState* ui_state;

	ConfigMap* config_map;

	//options
	StaticArray!(char, 64) player_name;

	this(GameStateHandler state_handler, EventHandler* event_handler, UIState* ui, ConfigMap* conf) {
		this.statehan = state_handler;
		this.evhan = event_handler;
		this.ui_state = ui;
		this.config_map = conf;
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

enum Resource {

	//shaders
	BASIC_SHADER,
	TEXT_SHADER,

	//units
	UNIT_TEXTURE

}

struct Game {

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;

	Tid network_thread;
	GameNetworkManager net_man;
	ConfigMap config_map;

	LinearAllocator master_allocator;
	LinearAllocator* resource_allocator;
	LinearAllocator* system_allocator;

	float frametime, updatetime, drawtime;
	FontAtlas* debug_atlas;
	Console* console;

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.evhan = evhan;
		this.ui_state = UIState();
		this.state = new GameStateHandler();

		this.master_allocator = LinearAllocator(65536);

		alias ma = master_allocator;
		this.resource_allocator = ma.alloc!(LinearAllocator)(8192, &master_allocator);
		this.system_allocator = ma.alloc!(LinearAllocator)(16384, &master_allocator);
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
		this.console = system_allocator.alloc!(Console)(debug_atlas);

	}

	void run() {

		//load game resources
		load_resources();

		//upload vertices for ui to gpu, set up shaders.
		ui_state.init();
	
		network_thread = spawn(&launch_peer, thisTid); //pass game thread so it can pass recieved messages back
		net_man = system_allocator.alloc!(GameNetworkManager)(network_thread);

		alias ra = system_allocator;
		state.add_state(ra.alloc!(MenuState)(state, evhan, &ui_state, net_man), State.MENU);
		state.add_state(ra.alloc!(MatchState)(state, evhan, &ui_state, net_man, console, debug_atlas), State.GAME);
		state.add_state(ra.alloc!(JoiningState)(state, evhan, &ui_state, net_man), State.JOIN);
		state.add_state(ra.alloc!(LobbyState)(state, evhan, &ui_state, net_man), State.LOBBY);
		state.add_state(ra.alloc!(WaitingState)(state, evhan, &ui_state, net_man), State.WAIT);
		state.add_state(ra.alloc!(OptionsState)(state, evhan, &ui_state, &config_map), State.OPTIONS);
		state.push_state(State.MENU);

		evhan.add_listener(&ui_state.update_ui);
		evhan.bind_keyevent(SDL_SCANCODE_RALT, &window.toggle_wireframe);
		evhan.bind_keyevent(SDL_SCANCODE_LCTRL, () => send(network_thread, Command.PING));
		evhan.bind_keyevent(SDL_SCANCODE_LALT, () => send(network_thread, Command.STATS));

		evhan.add_listener(&console.handle_event);
		evhan.bind_keyevent(SDL_SCANCODE_TAB, &console.toggle);
		evhan.bind_keyevent(SDL_SCANCODE_BACKSPACE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_DELETE, &console.del);
		evhan.bind_keyevent(SDL_SCANCODE_RETURN, &console.run);
		evhan.bind_keyevent(SDL_SCANCODE_DOWN, &console.get_prev);
		evhan.bind_keyevent(SDL_SCANCODE_UP, &console.get_next);

		import core.thread : Thread;
		import std.datetime : Duration, StopWatch, TickDuration;
		
		StopWatch sw;
		auto iter = TickDuration.from!("msecs")(16);
		auto last = TickDuration.from!("msecs")(0);

		import blindfire.engine.console : ConsoleCommand;
		console.bind_command(ConsoleCommand.SET_TICKRATE, 
			(Console* console, in char[] args) {
				int tickrate = to!int(args);
				iter = TickDuration.from!("msecs")(1000/tickrate);
		});

		console.bind_command(ConsoleCommand.PUSH_STATE, 
			(Console* console, in char[] args) {
				int new_state = to!int(args);
				if (new_state >= State.min && new_state <= State.max) {
					state.push_state(cast(State)new_state);
				}
		});

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
				evhan.handle_events();
				update(1.0);
				last = sw.peek();
				updatetime = ut_sw.peek().msecs;
				ut_sw.reset();

			}

			dt_sw.start();
			window.render_clear();
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

		net_man.send_message(Command.TERMINATE);

	}

} //Game
