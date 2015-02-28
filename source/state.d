module sundownstandoff.state;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.eventhandler;
import sundownstandoff.window;
import sundownstandoff.ui;

alias StateID = ulong;

enum State {

	MENU = 0,
	GAME = 1

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

	this(EventHandler* evhan) {

		evhan.bind_mousebtn(1, &print_something, KeyState.DOWN);
		evhan.bind_mousemov(&move_something);

	}

	void print_something(int x, int y) {
		writefln("Clicked something.. %d, %d", x, y);
	}

	void move_something(int x, int y) {
		writefln("Moved to x: %d y: %d", x, y);
	}

	override void update(double dt) {
		//do menu stuff
	}

	override void draw(Window* window) {

		int bgcolor = 0xca8142;
		int menucolor = 0x428bca;
		int itemcolor = 0x8bca42;

		uint width = 512, height = 384;
		draw_rectangle(window, true, 0, 0, window.width, window.height, bgcolor);
		draw_rectangle(window, true, window.width/2-width/2, window.height/2-height/2, width, height, menucolor);

		uint item_width = height / 2, item_height = 32;
		draw_rectangle(window, true, window.width/2-item_width/2, window.height/2-item_height/2 - item_height, item_width, item_height, itemcolor);
		if(do_button(window, true, window.width/2-item_width/2, window.height/2-item_height/2 + item_height/2, item_width, item_height, itemcolor)) {
			writefln("wut");
		}

	}

} //MenuState

final class MatchState : GameState {

	this(EventHandler* evhan) {
		
	}

	override void update(double dt) {

	}

	override void draw(Window* window) {

	}

} //MatchState
