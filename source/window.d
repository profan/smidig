module sundownstandoff.window;

import std.stdio : writefln;
import std.string : toStringz;

import derelict.sdl2.sdl;

struct Window {

	bool alive;
	SDL_Window* window;
	SDL_Renderer* renderer;

	this(in char[] title, uint width, uint height) {
		this.window = SDL_CreateWindow(
			toStringz(title), 
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			width, height,
			0);
		
		assert(window != null);
		renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
		assert(renderer != null);

		alive = true;	

	}

	~this() {

		SDL_DestroyRenderer(renderer);
		SDL_DestroyWindow(window);

	}

	void render_clear() {
		SDL_RenderClear(renderer);
	}

	void render_present() {
		SDL_RenderPresent(renderer);
	}

	void handle_events(ref SDL_Event ev) {
		if (ev.type == SDL_QUIT) {
			alive = false;
		}
	}

} //Window
