module sundownstandoff.game;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.window;
import sundownstandoff.eventhandler;
import sundownstandoff.state;

struct Game {

	Window* window;
	EventHandler* evhan;
	GameState state;

	this(Window* window, EventHandler* evhan) {
		this.window = window;
		this.evhan = evhan;
	}

	void update(double dt) {

		//wow

	}

	void draw() {

		//such draw

	}

	void run() {
	
		while(window.alive) {

			evhan.handle_events();

			window.render_clear();
			update(1.0);
			draw();

			window.render_present();

		}

	}

} //Game
