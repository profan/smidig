import std.stdio : writefln;
import std.c.process : exit;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.mixer;
import derelict.sdl2.ttf;

import derelict.openal.al;
import derelict.alure.alure;
import derelict.opengl3.gl;
import derelict.freetype.ft;
import derelict.util.loader;
import derelict.util.exception;

import blindfire.game;
import blindfire.engine.window;
import blindfire.engine.eventhandler;

const uint DEFAULT_WINDOW_WIDTH = 640;
const uint DEFAULT_WINDOW_HEIGHT = 480;

ShouldThrow missingSymFunc( string symName ) {

	//introduced at a later version than what I can find as a binary on windows
	//also not used in the project, so lets not care about this dependency.
    if( symName == "FT_Gzip_Uncompress") {
        return ShouldThrow.No;
    }

    // Any other missing symbol should throw.
    return ShouldThrow.Yes;
}

void initialize_systems() {

	DerelictFT.missingSymbolCallback = &missingSymFunc;
	DerelictGL.missingSymbolCallback = &missingSymFunc;
	DerelictFT.missingSymbolCallback = &missingSymFunc;
	DerelictAL.missingSymbolCallback = &missingSymFunc;
	DerelictALURE.missingSymbolCallback = &missingSymFunc;

	DerelictSDL2.load();
	DerelictSDL2Image.load();
	DerelictSDL2Mixer.load();
	DerelictSDL2ttf.load();
	DerelictGL.load();
	DerelictFT.load();
	DerelictAL.load();
	DerelictALURE.load();

	if (TTF_Init() == -1) {
		writefln("[GAME] TTF_Init: %s\n", TTF_GetError());
		exit(2);
	}

}

void main() {

	initialize_systems();
	auto event_handler = EventHandler(SDL_GetKeyboardState(null));
	auto window = Window("Project Blindfire", DEFAULT_WINDOW_WIDTH, DEFAULT_WINDOW_HEIGHT);
	auto game = Game(&window, &event_handler);

	event_handler.add_listener(&window.handle_events);
	game.run();

}
