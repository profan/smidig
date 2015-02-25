module sundownstandoff.game;

import std.stdio : writefln;

import sundownstandoff.window;
import sundownstandoff.eventhandler;

struct Game {

	Window* window;
	EventHandler* evhan;

	this(Window* window, EventHandler* evhan) {
		this.window = window;
		this.evhan = evhan;
	}

	void update() {

		//wow

	}

	void draw() {

		//such draw

	}

	void run() {
	
		while(window.alive) {

			evhan.handle_events();

			window.render_clear();
			update();
			draw();

			window.render_present();

		}

	}

} //Game
