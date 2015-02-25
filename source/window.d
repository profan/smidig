module sundownstandoff.window;

import std.utf : toUTFz;
import std.stdio : writefln;

import derelict.sdl2.sdl;

struct Window {

	bool alive;
	char* c_title; //keep this here so the char* for toStringz doesn't point to nowhere!
	SDL_Window* window;
	SDL_Renderer* renderer;

	this(in char[] title, uint width, uint height) {
		this.c_title = toUTFz!(char*)(title);
		this.window = SDL_CreateWindow(
			c_title,
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

	@property const(char*) title() { return c_title; }
	@property void title(in char[] new_title) { c_title = toUTFz!(char*)(new_title); SDL_SetWindowTitle(window, c_title); }

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
