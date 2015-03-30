module blindfire.game;

import std.stdio : writefln;
import std.concurrency : send, spawn, receiveOnly, thisTid;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;

import blindfire.window;
import blindfire.eventhandler;
import blindfire.graphics;
import blindfire.state;
import blindfire.net;
import blindfire.gl;
import blindfire.ui;

final class MenuState : GameState {
	
	UIState* ui_state;
	GameStateHandler statehan;

	SDL_Texture* menu_title_texture;
	SDL_Texture* menu_join_texture;
	SDL_Texture* menu_create_texture;
	SDL_Texture* menu_quit_texture;

	Texture texture;
	Shader shader;
	Mesh mesh;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Window* window) {

		this.statehan = statehan;
		this.ui_state = state;

		int title_color = 0xffa500;
		int text_color = 0x0e72c9;
		menu_title_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Project Blindfire", 48, title_color);
		menu_join_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Join Game", 20, text_color);
		menu_create_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Create Game", 20, text_color);
		menu_quit_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Quit", 20, text_color);
	
	
		shader = Shader("shaders/basic");

		Vertex[3] vertices = [
			Vertex(Vec3f(-0.5, -0.5, 0.0), Vec2f(0.0, 0.0)),
			Vertex(Vec3f(0.0, 0.5, 0.0), Vec2f(0.5, 1.0)),
			Vertex(Vec3f(0.5, -0.5, 0.0), Vec2f(1.0, 0.0))
		];

		mesh = Mesh(vertices.ptr, vertices.length);
		texture = Texture("resource/img/dev_red_512_512.png");

	}
	
	override void enter() {

	}

	override void leave() {

	}


	override void update(double dt) {
	
	}

	override void draw(Window* window) {

		/*

		int bgcolor = 0xca8142;
		int menucolor = 0x428bca;
		int itemcolor = 0x8bca42;

		uint width = 512, height = window.height - window.height/3;
		draw_rectangle(window, DrawFlags.FILL, 0, 0, window.width, window.height, bgcolor);
		draw_rectangle(window, DrawFlags.FILL, window.width/2-width/2, window.height/2-height/2, width, height, menucolor);

		draw_label(window, menu_title_texture, window.width/2, window.height/4, 0, 0);

		uint item_width = height / 2, item_height = 32;
		if(do_button(ui_state, 1, window, true, window.width/2, window.height/2 - item_height/2, item_width, item_height, itemcolor, 255, menu_join_texture)) {
			statehan.push_state(State.JOIN);
		} //join

		if(do_button(ui_state, 2, window, true, window.width/2, window.height/2 + item_height/2*2, item_width, item_height, itemcolor, 255, menu_create_texture)) {
			statehan.push_state(State.WAIT);
		} //create
		
		if(do_button(ui_state, 3, window, true, window.width/2, window.height/2 + (item_height/2)*5, item_width, item_height, itemcolor, 255, menu_quit_texture)) {
			window.alive = false;
		} //quit

		*/

		shader.bind();
		texture.bind(1);
		mesh.draw();
		shader.unbind();

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
				statehan.push_state(State.GAME);
			}
		});

	}

	override void draw(Window* window) {

		int itemcolor = 0x8bca42;
		uint item_width = window.width/2, item_height = 32;
		if(do_button(ui_state, 4, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			statehan.pop_state();
		} //back to menu, cancel

	}

} //JoiningState

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

	import blindfire.netmsg : UpdateType, EntityType;
	StaticArray!(ubyte, 512) data;

	override void enter() {

		import std.random : uniform;

		auto x = uniform(128, 256);
		auto y = uniform(128, 256);

		player = create_unit(em, Vec2f(x, y), cast(EntityID*)null);
		
		//move this into create_unit?
		data.elements = 0;
		auto type = UpdateType.CREATE;
		data ~= (cast(ubyte*)&type)[0..type.sizeof];

		auto id = player;
		data ~= (cast(ubyte*)&player)[0..player.sizeof];

		auto ent_type = EntityType.UNIT;
		data ~= (cast(ubyte*)&ent_type)[0..ent_type.sizeof];

		auto vec2 = Vec2f(x, y);
		data ~= (cast(ubyte*)&vec2)[0..vec2.sizeof];
			
		send(network_thread, Command.UPDATE, data.array[0..data.elements].idup);

	}

	override void leave() {

		//delete the player entity's components
		em.unregister_component(player);

		//disconnect since when in this state, we will have been connected.
		send(network_thread, Command.DISCONNECT);

	}

	override void update(double dt) {

		//figure out way to split into updating and drawing properly.
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
		send(network_thread, Command.CREATE);
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
			statehan.pop_state();
		} //back to menu

	}

} //WaitingState

struct Game {

	import std.uuid;

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;
	
	Tid network_thread;
	ClientID client_uuid;

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.evhan = evhan;
		this.ui_state = UIState();
		this.state = new GameStateHandler();
		this.client_uuid = randomUUID();
		
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
		state.draw(window);

	}

	void run() {
	
		network_thread = spawn(&launch_peer, thisTid, client_uuid); //pass game thread so it can pass recieved messages back
		
		state.add_state(new MenuState(state, evhan, &ui_state, window), State.MENU);
		state.add_state(new MatchState(state, evhan, &ui_state, window, network_thread, client_uuid), State.GAME);
		state.add_state(new JoiningState(state, evhan, &ui_state, network_thread), State.JOIN);
		state.add_state(new WaitingState(state, evhan, &ui_state, network_thread), State.WAIT);
		state.push_state(State.MENU);

		evhan.add_listener(&this.update_ui);
		evhan.bind_keyevent(SDL_SCANCODE_SPACE, &window.toggle_wireframe);
		evhan.bind_keyevent(SDL_SCANCODE_LCTRL, () => send(network_thread, Command.PING));

		import core.thread : Thread;
		import std.datetime : Duration, StopWatch, TickDuration;
		
		StopWatch sw;
		auto iter = TickDuration.from!("msecs")(16);
		auto last = TickDuration.from!("msecs")(0);

		sw.start();
		auto start_time = sw.peek();
		while(window.alive) {

			if (sw.peek() - last > iter) {

				evhan.handle_events();
				window.render_clear();
				update(1.0);
				ui_state.before_ui();
				draw();
				ui_state.reset_ui();
				window.render_present();
				last = sw.peek();

			}

			auto diff = cast(Duration)(last - sw.peek()) + iter;
			if (diff > dur!("hnsecs")(0)) {
				Thread.sleep(diff);
			}

		}

		send(network_thread, Command.TERMINATE);

	}

} //Game
