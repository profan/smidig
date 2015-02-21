module sundownstandoff.eventhandler;

import std.stdio : writefln;

import derelict.sdl2.sdl;

alias void delegate(ref SDL_Event) EventDelegate;

struct EventHandler {

	SDL_Event ev;
	EventDelegate[] delegates;

	void add_listener(EventDelegate ed) {
		delegates ~= ed;
	}

	void handle_events() {
		
		while(SDL_PollEvent(&ev)) {
				
			foreach(ref receiver; delegates) {
				receiver(ev);
			}

		}

	}

} //EventHandler
