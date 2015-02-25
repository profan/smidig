module sundownstandoff.state;

import derelict.sdl2.sdl;

import sundownstandoff.window;

abstract class GameState {

	void update(double dt);
	void draw(Window* window);

} //GameState

class MenuState : GameState {

	final override void update(double dt) {
		//do menu stuff
	}

	final override void draw(Window* window) {

		uint width = 512, height = 384;
		SDL_Rect rect = {x: 640/2-width/2, y: 480/2-height/2, w: width, h: height};
		SDL_RenderDrawRect(window.renderer, &rect);

	}

} //MenuState

class MatchState : GameState {

	final override void update(double dt) {

	}

	final override void draw(Window* window) {

	}

} //MatchState
