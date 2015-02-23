module sundownstandoff.game;

import std.stdio : writefln;

import sundownstandoff.window;
import sundownstandoff.eventhandler;

struct Game {

	Window window;
	EventHandler evhan;

	this(ref Window window, ref EventHandler evhan) {
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

			window.render_clear();

			evhan.handle_events();
			update();
			draw();

			window.render_present();

		}

	}

} //Game
