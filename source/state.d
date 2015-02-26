module sundownstandoff.state;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.eventhandler;
import sundownstandoff.window;

abstract class GameState {

	void update(double dt);
	void draw(Window* window);

} //GameState

final class MenuState : GameState {

	this(EventHandler* evhan) {

		evhan.bind_mousebtn(1, &print_something, KeyState.DOWN);

	}

	void print_something(int x, int y) {
		writefln("Clicked something.. %d, %d", x, y);
	}

	override void update(double dt) {
		//do menu stuff
	}

	override void draw(Window* window) {

		uint width = 512, height = 384;
		SDL_Rect rect = {x: 640/2-width/2, y: 480/2-height/2, w: width, h: height};
		SDL_RenderDrawRect(window.renderer, &rect);

	}

} //MenuState

final class MatchState : GameState {

	override void update(double dt) {

	}

	override void draw(Window* window) {

	}

} //MatchState
