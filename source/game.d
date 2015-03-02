module sundownstandoff.game;

import std.stdio : writefln;

import derelict.sdl2.sdl;

import sundownstandoff.window;
import sundownstandoff.eventhandler;
import sundownstandoff.state;
import sundownstandoff.ui;

struct Game {

	Window* window;
	EventHandler* evhan;
	GameStateHandler state;
	UIState ui_state;

	this(Window* window, EventHandler* evhan) {

		this.window = window;
		this.evhan = evhan;
		this.ui_state = UIState();
		this.state = new GameStateHandler();
		this.state.add_state(new MatchState(state, evhan, &ui_state), State.GAME);
		this.state.add_state(new MenuState(state, evhan, &ui_state, window), State.MENU);
		this.state.push_state(State.GAME);
		this.state.push_state(State.MENU);

		this.evhan.add_listener(&this.update_ui);

	}

	void update_ui(ref SDL_Event ev) {
		SDL_GetMouseState(&ui_state.mouse_x, &ui_state.mouse_y);
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
