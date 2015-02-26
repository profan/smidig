module sundownstandoff.state;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.eventhandler;
import sundownstandoff.window;

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
		stack = stack[0..$-2];
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

		uint width = 512, height = 384;
		SDL_Rect rect = {x: window.width/2-width/2, y: window.height/2-height/2, w: width, h: height};
		SDL_RenderDrawRect(window.renderer, &rect);

	}

} //MenuState

final class MatchState : GameState {

	override void update(double dt) {

	}

	override void draw(Window* window) {

	}

} //MatchState
