module blindfire.game;

import std.stdio : writefln;
import std.concurrency : send, spawn, receiveOnly, thisTid;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;
import derelict.freetype.ft;

import blindfire.window;
import blindfire.eventhandler;
import blindfire.graphics;
import blindfire.resource;
import blindfire.state;
import blindfire.defs;
import blindfire.net;
import blindfire.gl;
import blindfire.ui;

final class MenuState : GameState {
	
	UIState* ui_state;
	GameStateHandler statehan;

	TTF_Font* title_font;
	TTF_Font* menu_font;

	Text* menu_title_texture;
	Text* menu_join_texture;
	Text* menu_create_texture;
	Text* menu_quit_texture;
	
	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Window* window) {

		this.statehan = statehan;
		this.ui_state = state;

	}
	
	override void enter() {

		if (this.menu_title_texture is null) {
			auto rm = ResourceManager.get();
			this.menu_title_texture = rm.get_resource!(Text)(Resource.MENU_TITLE_TEXTURE);
			this.menu_join_texture = rm.get_resource!(Text)(Resource.MENU_JOIN_TEXTURE);
			this.menu_create_texture = rm.get_resource!(Text)(Resource.MENU_CREATE_TEXTURE);
			this.menu_quit_texture = rm.get_resource!(Text)(Resource.MENU_QUIT_TEXTURE);
		}

	}

	override void leave() {

	}


	override void update(double dt) {
	
	}

	override void draw(Window* window) {

		int bgcolor = 0xca8142;
		int menucolor = 0x428bca;
		int itemcolor = 0x8bca42;

		uint width = 512, height = window.height - window.height/3;
		draw_rectangle(window, ui_state, DrawFlags.FILL, 0, 0, window.width, window.height, bgcolor);
		draw_rectangle(window, ui_state, DrawFlags.FILL, window.width/2-width/2, window.height/2-height/2, width, height, menucolor);

		draw_label(window, menu_title_texture, window.width/2, window.height/4, 0, 0);

		uint item_width = height / 2, item_height = 32;
		if (do_button(ui_state, 1, window, true, window.width/2, window.height/2 - item_height/2, item_width, item_height, itemcolor, 255, menu_join_texture)) {
			statehan.push_state(State.JOIN);
		} //join

		if (do_button(ui_state, 2, window, true, window.width/2, window.height/2 + item_height/2*2, item_width, item_height, itemcolor, 255, menu_create_texture)) {
			statehan.push_state(State.LOBBY);
		} //create
		
		if (do_button(ui_state, 3, window, true, window.width/2, window.height/2 + (item_height/2)*5, item_width, item_height, itemcolor, 255, menu_quit_texture)) {
			window.alive = false;
		} //quit

		float sx = 2.0 / window.width;
		float sy = 2.0 / window.height;
		//ui_state.font_atlas.render_text("The Quick Brown Fox Jumps Over The Lazy Dog",
        //      -1 + 8 * sx,   1 - 50 * sy,    sx, sy, 0x428bca);
		ui_state.font_atlas.render_text("HELLO WORLD", -0.5, 0, sx, sy, 0x428bca);
		
	}

} //MenuState

final class JoiningState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	Tid network_thread;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Tid net_tid) {
		this.statehan = statehan;
		this.ui_state = state;
		this.network_thread = net_tid;
	}

	override void enter() {
		InternetAddress addr = new InternetAddress("localhost", 12000);
		send(network_thread, Command.CONNECT, cast(shared)addr);
	}

	override void leave() {

	}

	override void update(double dt) {
		
		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {
			if (cmd == Command.CREATE) {
				writefln("[GAME] Received %s from net thread.", to!string(cmd));
				statehan.pop_state();
				statehan.push_state(State.LOBBY);
			} else if (cmd == Command.DISCONNECT) {
				writefln("[GAME] Received %s from net thread, going back to menu.", to!string(cmd));
				statehan.pop_state();
			}
		});

	}

	override void draw(Window* window) {

		int itemcolor = 0x8bca42;
		uint item_width = window.width/2, item_height = 32;
		if (do_button(ui_state, 4, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			statehan.pop_state();
		} //back to menu, cancel

	}

} //JoiningState


// state handles match-preparation stage (whatever that may be?)
final class LobbyState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	Tid network_thread;

	ClientID uuid;

	Text* lobby_start_texture;
	Text* lobby_quit_texture;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Tid net_tid, ClientID uuid) {
		this.statehan = statehan;
		this.ui_state = state;
		this.network_thread = net_tid;
		this.uuid = uuid;
	}

	void enter() {

		if (lobby_start_texture is null) {
			auto rm = ResourceManager.get();
			lobby_start_texture = rm.get_resource!(Text)(Resource.LOBBY_START_TEXTURE);
			lobby_quit_texture = rm.get_resource!(Text)(Resource.LOBBY_QUIT_TEXTURE);
		}

		send(network_thread, Command.CREATE);

	}

	void leave() {

	}

	void update(double dt) {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {
			if (cmd == Command.CREATE) {
				writefln("[GAME] Received %s from net thread.", to!string(cmd));
				statehan.pop_state();
				statehan.push_state(State.GAME);
			} else if (cmd == Command.DISCONNECT) {
				writefln("[GAME] Received %s from net thread, going back to menu.", to!string(cmd));
				statehan.pop_state();
			}
		});

	}

	void draw(Window* window) {

		int bgcolor = 0xbc8142;
		draw_rectangle(window, ui_state, DrawFlags.FILL, 0, 0, window.width, window.height, bgcolor);

		int itemcolor = 0x8bca42;
		uint item_width = window.width / 2, item_height = 32;

		//bottom left for quit button
		if (do_button(ui_state, 8, window, true, item_width/2, window.height - item_height, item_width, item_height, itemcolor, 255, lobby_start_texture)) {
			send(network_thread, Command.CREATE);
			statehan.pop_state();
			statehan.push_state(State.GAME);
		}

		if (do_button(ui_state, 9, window, true, item_width + item_width/2, window.height - item_height, item_width, item_height, itemcolor, 255, lobby_quit_texture)) {
			send(network_thread, Command.DISCONNECT);
			statehan.pop_state();
		} //back to menu

	}

} //LobbyState

final class MatchState : GameState {

	import profan.ecs : EntityID, EntityManager;
	import blindfire.action : SelectionBox;
	import blindfire.ents : create_unit;
	import blindfire.sys;

	UIState* ui_state;
	GameStateHandler statehan;
	Tid network_thread;

	SelectionBox sbox;
	EntityManager em;

	EntityID player;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Window* window, Tid net_tid, ClientID uuid) {
		this.statehan = statehan;
		this.ui_state = state;
		this.network_thread = net_tid;

		this.em = new EntityManager(uuid);
		this.em.add_system(new TransformManager());
		this.em.add_system(new CollisionManager());
		this.em.add_system(new SpriteManager());
		this.em.add_system(new InputManager());
		this.em.add_system(new NetworkManager(network_thread, uuid));
		this.em.add_system(new OrderManager(&sbox));

		//where do these bindings actually belong? WHO KNOWS
		evhan.bind_mousebtn(1, &sbox.set_active, KeyState.DOWN);
		evhan.bind_mousebtn(1, &sbox.set_inactive, KeyState.UP);
		evhan.bind_mousebtn(3, &sbox.set_order, KeyState.UP);
		evhan.bind_mousemov(&sbox.set_size);

	}

	StaticArray!(ubyte, 512) data;

	override void enter() {

		import blindfire.netmsg : UpdateType, EntityType;
		import std.random : uniform;

		auto x = uniform(128, 256);
		auto y = uniform(128, 256);

		auto rm = ResourceManager.get();
		Shader* s = rm.get_resource!(Shader)(Resource.BASIC_SHADER);
		Texture* t = rm.get_resource!(Texture)(Resource.UNIT_TEXTURE);

		player = create_unit(em, Vec2f(x, y), cast(EntityID*)null, s, t);
		
		//TODO move this into create_unit?
		data.elements = 0;
		auto type = UpdateType.CREATE;
		data ~= (cast(ubyte*)&type)[0..type.sizeof];

		auto id = player;
		data ~= (cast(ubyte*)&player)[0..player.sizeof];

		auto ent_type = EntityType.UNIT;
		data ~= (cast(ubyte*)&ent_type)[0..ent_type.sizeof];

		auto vec2 = Vec2f(x, y);
		data ~= (cast(ubyte*)&vec2)[0..vec2.sizeof];
			
		send(network_thread, Command.UPDATE, cast(immutable(ubyte)[])data.array[0..data.elements].idup);

	}

	override void leave() {

		//delete the player entity's components
		em.unregister_component(player);

		//disconnect since when in this state, we will have been connected.
		send(network_thread, Command.DISCONNECT);

	}

	override void update(double dt) {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {
			if (cmd == Command.DISCONNECT) {
				writefln("[GAME] Received %s from net thread, going back to menu.", to!string(cmd));
				statehan.pop_state();
			}
		});

		em.tick!(UpdateSystem)();

	}

	override void draw(Window* window) {

		em.tick!(DrawSystem)(window);

		sbox.draw(window);

		int itemcolor = 0x8bca42;
		uint item_width = window.width / 2, item_height = 32;
		if(do_button(ui_state, 5, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			statehan.pop_state();
		} //back to menu

	}

} //MatchState

//when waiting for another player to connect?
final class WaitingState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;
	Tid network_thread;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Tid net_tid) {
		this.statehan = statehan;
		this.ui_state = state;
		this.network_thread = net_tid;
	}

	override void enter() {
	}

	override void leave() {
	
	}
	
	override void update(double dt) {

		auto result = receiveTimeout(dur!("nsecs")(1),
		(Command cmd) {
			if (cmd == Command.CREATE) {
				writefln("[GAME] Received %s from net thread.", to!string(cmd));
				statehan.pop_state();
				statehan.push_state(State.GAME);
			}
		});

	}

	override void draw(Window* window) {

		int itemcolor = 0x8bca42;
		uint item_width = window.width / 2, item_height = 32;
		if(do_button(ui_state, 6, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			send(network_thread, Command.DISCONNECT);
			statehan.pop_state();
		} //back to menu

	}

} //WaitingState

enum Resource {

	//shaders
	BASIC_SHADER,
	TEXT_SHADER,

	//textures
	MENU_TITLE_TEXTURE,
	MENU_JOIN_TEXTURE,
	MENU_CREATE_TEXTURE,
	MENU_QUIT_TEXTURE,

	LOBBY_START_TEXTURE,
	LOBBY_QUIT_TEXTURE,

	//units
	UNIT_TEXTURE

}

struct Game {

	import std.uuid : randomUUID;

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;
	
	Tid network_thread;
	ClientID client_uuid;

	import blindfire.memory;
	LinearAllocator resource_allocator;
	LinearAllocator system_allocator;

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.evhan = evhan;
		this.ui_state = UIState();
		this.state = new GameStateHandler();
		this.client_uuid = randomUUID();
		this.resource_allocator = LinearAllocator(8112);
		this.system_allocator = LinearAllocator(16384);
		
	}

	void update_ui(ref SDL_Event ev) {

		ui_state.mouse_buttons = SDL_GetMouseState(&ui_state.mouse_x, &ui_state.mouse_y);

	}
	
	void update(double dt) {

		//wow
		state.update(dt);

	}

	void draw() {

		//such draw
		ui_state.before_ui();
		state.draw(window);
		ui_state.reset_ui();

	}

	void load_resources() {

		import blindfire.gl;

		alias ra = resource_allocator;
		auto rm = ResourceManager.get();

		//shaders
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = ra.alloc!(Shader)("shaders/basic", attributes[0..attributes.length], uniforms[0..uniforms.length]);
		rm.set_resource!(Shader)(shader, Resource.BASIC_SHADER);

		AttribLocation[1] text_attribs = [AttribLocation(0, "coord")];
		char[16][1] text_uniforms = ["color"];
		auto text_shader = ra.alloc!(Shader)("shaders/text", text_attribs[0..text_attribs.length], text_uniforms[0..text_uniforms.length]); 
		rm.set_resource!(Shader)(text_shader, Resource.TEXT_SHADER);

		//textures
		auto unit_tex = ra.alloc!(Texture)("resource/img/dude2.png");
		rm.set_resource!(Texture)(unit_tex, Resource.UNIT_TEXTURE);

		//menu resourcs
		auto title_font = TTF_OpenFont("fonts/OpenSans-Bold.ttf", 48);
		auto menu_font = TTF_OpenFont("fonts/OpenSans-Bold.ttf", 20);
		scope(exit) {
			TTF_CloseFont(title_font);
			TTF_CloseFont(menu_font);
		}

		if (menu_font == null) {
			writefln("[GAME] Failed to open font: %s", "fonts/OpenSans-Bold.ttf");
		}

		int title_color = 0x0e72c9;
		int text_color = 0x8142ca;
		char[64][4] menu_text = ["Project Blindfire", "Join Game", "Create Game", "Quit"];
		auto menu_title_texture = ra.alloc!(Text)(title_font, menu_text[0], title_color, shader);
		auto menu_join_texture = ra.alloc!(Text)(menu_font, menu_text[1], text_color, shader);
		auto menu_create_texture = ra.alloc!(Text)(menu_font, menu_text[2], text_color, shader);
		auto menu_quit_texture = ra.alloc!(Text)(menu_font, menu_text[3], text_color, shader);

		rm.set_resource!(Text)(menu_title_texture, Resource.MENU_TITLE_TEXTURE);
		rm.set_resource!(Text)(menu_join_texture, Resource.MENU_JOIN_TEXTURE);
		rm.set_resource!(Text)(menu_create_texture, Resource.MENU_CREATE_TEXTURE);
		rm.set_resource!(Text)(menu_quit_texture, Resource.MENU_QUIT_TEXTURE);

		//lobby resources
		char[64][2] lobby_text = ["Start Game", "Exit Lobby"];
		auto lobby_start_texture = ra.alloc!(Text)(menu_font, lobby_text[0], title_color, shader);
		auto lobby_quit_texture = ra.alloc!(Text)(menu_font, lobby_text[1], title_color, shader);

		rm.set_resource!(Text)(lobby_start_texture, Resource.LOBBY_START_TEXTURE);
		rm.set_resource!(Text)(lobby_quit_texture, Resource.LOBBY_QUIT_TEXTURE);

	}

	void run() {

		//load game resources
		load_resources();

		//upload vertices for ui to gpu, set up shaders.
		ui_state.init();
	
		network_thread = spawn(&launch_peer, thisTid, client_uuid); //pass game thread so it can pass recieved messages back

		alias ra = system_allocator;	
		state.add_state(ra.alloc!(MenuState)(state, evhan, &ui_state, window), State.MENU);
		state.add_state(ra.alloc!(MatchState)(state, evhan, &ui_state, window, network_thread, client_uuid), State.GAME);
		state.add_state(ra.alloc!(JoiningState)(state, evhan, &ui_state, network_thread), State.JOIN);
		state.add_state(ra.alloc!(LobbyState)(state, evhan, &ui_state, network_thread, client_uuid), State.LOBBY);
		state.add_state(ra.alloc!(WaitingState)(state, evhan, &ui_state, network_thread), State.WAIT);
		state.push_state(State.MENU);

		evhan.add_listener(&this.update_ui);
		evhan.bind_keyevent(SDL_SCANCODE_SPACE, &window.toggle_wireframe);
		evhan.bind_keyevent(SDL_SCANCODE_LCTRL, () => send(network_thread, Command.PING));
		evhan.bind_keyevent(SDL_SCANCODE_LALT, () => send(network_thread, Command.STATS));

		import core.thread : Thread;
		import std.datetime : Duration, StopWatch, TickDuration;
		
		StopWatch sw;
		auto iter = TickDuration.from!("msecs")(100);
		auto last = TickDuration.from!("msecs")(0);

		sw.start();
		auto start_time = sw.peek();
		while(window.alive) {

			if (sw.peek() - last > iter) {

				evhan.handle_events();
				update(1.0);
				last = sw.peek();

			}

			window.render_clear();
			draw();
			window.render_present();

			auto diff = cast(Duration)(last - sw.peek()) + iter;
			if (diff > dur!("hnsecs")(0)) {
				Thread.sleep(diff);
			}

		}

		send(network_thread, Command.TERMINATE);

	}

} //Game
