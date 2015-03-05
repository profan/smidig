module sundownstandoff.state;

import std.stdio : writefln;
import core.stdc.stdlib : exit;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;

import sundownstandoff.eventhandler;
import sundownstandoff.graphics;
import sundownstandoff.window;
import sundownstandoff.ui;

alias StateID = ulong;

enum State {

	MENU = 0,
	GAME = 1,
	JOIN = 2,
	WAIT = 3

} //State

class GameStateHandler {

	GameState[] stack;
	GameState[StateID] states;

	this() {
		//asd
	}

	void add_state(GameState state, State type) {
		states[type] = state;
	}

	void push_state(State state) {
		stack ~= states[state];
	}

	GameState pop_state() {
		GameState st = stack[$-1];
		stack = stack[0..$-1];
		return st;
	}

	void update(double dt) {
		stack[$-1].update(dt);
	}

	void draw(Window* window) {
		stack[$-1].draw(window);
	}

} //GameStateHandler

abstract class GameState {

	void update(double dt);
	void draw(Window* window);

} //GameState

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
		evhan.bind_mousebtn(1, &print_something, KeyState.DOWN);

		int title_color = 0xffa500;
		int text_color = 0x0e72c9;
		menu_title_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Sundown Standoff", 48, title_color);
		menu_join_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Join Game", 20, text_color);
		menu_create_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Create Game", 20, text_color);
		menu_quit_texture = create_font_texture(window, "fonts/OpenSans-Bold.ttf", "Quit", 20, text_color);

	}

	void print_something(int x, int y) {
		writefln("Clicked something.. %d, %d", x, y);
	}

	override void update(double dt) {
		//do menu stuff
	}

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
			statehan.push_state(State.GAME);
		} //create
		
		if(do_button(ui_state, 3, window, true, window.width/2, window.height/2 + (item_height/2)*5, item_width, item_height, itemcolor, 255, menu_quit_texture)) {
			exit(0);
		} //quit

	}

} //MenuState

final class JoiningState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state) {
		this.statehan = statehan;
		this.ui_state = state;
	}

	override void update(double dt) {
		//much update
	}

	override void draw(Window* window) {
		int item_width = window.width/2, item_height = 32, itemcolor = 0x428bca;
		if(do_button(ui_state, 4, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			statehan.pop_state();
		}
	}

} //JoiningState

final class MatchState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state) {
		this.statehan = statehan;
		this.ui_state = state;
	}

	override void update(double dt) {

	}

	override void draw(Window* window) {

		int itemcolor = 0x8bca42;
		uint item_width = window.width / 2, item_height = 32;
		if(do_button(ui_state, 5, window, true, window.width/2, window.height/2 - item_height, item_width, item_height, itemcolor)) {
			statehan.pop_state();
		}		

	}

} //MatchState



//when waiting for another player to connect?
final class WaitingState : GameState {

	UIState* ui_state;
	GameStateHandler statehan;

	this(GameStateHandler statehan, EventHandler* evhan, UIState* state) {
		this.statehan = statehan;
		this.ui_state = state;
	}
	
	override void update(double dt) {
		//...
	}

	override void draw(Window* window) {
		//...
	}

} //WaitingState
