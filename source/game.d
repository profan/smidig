module sundownstandoff.game;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.window;
import sundownstandoff.eventhandler;
import sundownstandoff.state;

struct Game {

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;

	this(Window* window, EventHandler* evhan) {
		this.window = window;
		this.evhan = evhan;
		this.state = new GameStateHandler();
		this.state.add_state(new MatchState(evhan), State.GAME);
		this.state.add_state(new MenuState(evhan), State.MENU);
		this.state.push_state(State.GAME);
		this.state.push_state(State.MENU);
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
	
		while(window.alive) {

			evhan.handle_events();

			window.render_clear();
			update(1.0);
			draw();

			window.render_present();

		}

	}

} //Game
