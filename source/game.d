module sundownstandoff.game;

import std.math;
import std.concurrency;
import std.stdio : writefln;
import std.file : read, readText;
import core.stdc.stdlib : malloc, free, exit;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;

import sundownstandoff.window;
import sundownstandoff.eventhandler;
import sundownstandoff.graphics;
import sundownstandoff.state;
import sundownstandoff.net;
import sundownstandoff.gl;
import sundownstandoff.ui;

final class MenuState : GameState {
	
	UIState* ui_state;
	GameStateHandler statehan;

	SDL_Texture* menu_title_texture;
	SDL_Texture* menu_join_texture;
	SDL_Texture* menu_create_texture;
	SDL_Texture* menu_quit_texture;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state, Window* window) {

		this.statehan = statehan;
		this.ui_state = state;

		int title_color = 0xffa500;
		int text_color = 0x0e72c9;
		menu_title_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Sundown Standoff", 48, title_color);
		menu_join_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Join Game", 20, text_color);
		menu_create_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Create Game", 20, text_color);
		menu_quit_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Quit", 20, text_color);

		// Create Vertex Array Object
		GLuint vao;
		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		// Create a Vertex Buffer Object and copy the vertex data to it
		GLuint vbo;
		glGenBuffers(1, &vbo);

		GLfloat[15] vertices = [
			0.0f,  0.5f, 1.0f, 0.0f, 0.0f, // Vertex 1 (X, Y) Red
			0.5f, -0.5f, 0.0f, 1.0f, 0.0f, // Vertex 2 (X, Y) Green
			-0.5f, -0.5f, 0.0f, 0.0f, 1.0f  // Vertex 3 (X, Y) Blue
		];

		glBindBuffer(GL_ARRAY_BUFFER, vbo);
		glBufferData(GL_ARRAY_BUFFER, vertices.sizeof, cast(void*)vertices, GL_STATIC_DRAW);
		
		auto vs = cast(char*)read("shaders/triangle.vs", 2048);
		GLuint triangle_vs = compile_shader(&vs, GL_VERTEX_SHADER);
		
		auto fs = cast(char*)read("shaders/triangle.fs", 2048);
		GLuint triangle_fs = compile_shader(&fs, GL_FRAGMENT_SHADER);

		GLuint program = create_shader_program(triangle_vs, triangle_fs);
		glUseProgram(program);

		GLint posAttrib = glGetAttribLocation(program, "position");
		glEnableVertexAttribArray(posAttrib);
		glVertexAttribPointer(posAttrib, 2, GL_FLOAT, GL_FALSE, 5*GLfloat.sizeof, null);

		GLint colAttrib = glGetAttribLocation(program, "color");
		glEnableVertexAttribArray(colAttrib);
		glVertexAttribPointer(colAttrib, 3, GL_FLOAT, GL_FALSE, 5*GLfloat.sizeof, cast(void*)(2*GLfloat.sizeof));

	}
	
	override void enter() {

	}

	override void leave() {

	}


	override void update(double dt) {
		//do menu stuff
	}


	override void draw(Window* window) {
		
		glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
		// Draw a triangle from the 3 vertices
		glDrawArrays(GL_TRIANGLES, 0, 3);

	}

	/*
	override void draw(Window* window) {

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

	} */

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

	}

	override void leave() {

	}

	override void update(double dt) {
		//much update
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
		//nonblocking receive to process messages from net thread
	}

	override void draw(Window* window) {

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
		//...
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

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;
	
	Tid network_thread;

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.evhan = evhan;
		this.ui_state = UIState();
		this.state = new GameStateHandler();
		
		
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
	
		network_thread = spawn(&launch_peer);
		
		state.add_state(new MenuState(state, evhan, &ui_state, window), State.MENU);
		state.add_state(new MatchState(state, evhan, &ui_state, network_thread), State.GAME);
		state.add_state(new JoiningState(state, evhan, &ui_state, network_thread), State.JOIN);
		state.add_state(new WaitingState(state, evhan, &ui_state, network_thread), State.WAIT);
		state.push_state(State.MENU);

		evhan.add_listener(&this.update_ui);

		while(window.alive) {

			evhan.handle_events();

			window.render_clear();
			update(1.0);
			ui_state.before_ui();
			draw();
			ui_state.reset_ui();

			window.render_present();

		}

		send(network_thread, Command.TERMINATE);

	}

} //Game
