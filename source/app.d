import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.mixer;
import derelict.sdl2.ttf;

import sundownstandoff.game;
import sundownstandoff.window;
import sundownstandoff.eventhandler;

const uint DEFAULT_WINDOW_WIDTH = 640;
const uint DEFAULT_WINDOW_HEIGHT = 480;

void initialize_systems() {

	DerelictSDL2.load();
	DerelictSDL2Image.load();
	DerelictSDL2Mixer.load();
	DerelictSDL2ttf.load();

}

void main() {

	initialize_systems();
	auto event_handler = EventHandler();
	auto window = Window("Sundown Standoff", DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
	event_handler.add_listener(&window.handle_events);
	auto game = Game(window, event_handler);
	game.run();

}
