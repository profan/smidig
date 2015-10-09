import std.stdio : writefln;
import std.c.process : exit;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.ttf;

import derelict.openal.al;
import derelict.alure.alure;
import derelict.opengl3.gl;
import derelict.freetype.ft;
import derelict.imgui.imgui;
import derelict.util.loader;
import derelict.util.exception;

import blindfire.game;
import blindfire.engine.window;
import blindfire.engine.eventhandler;

const uint DEFAULT_WINDOW_WIDTH = 640;
const uint DEFAULT_WINDOW_HEIGHT = 480;

ShouldThrow missingSymFunc( string symName ) {

	//introduced at a later version than what I can find as a binary on windows
	//also not used in the project, so lets not care about this dependency (gzip_uncompress)

	if (symName == "FT_Gzip_Uncompress"
		|| symName == "SDL_QueueAudio"
		|| symName == "SDL_GetQueuedAudioSize"
		|| symName == "SDL_ClearQueuedAudio"
		|| symName == "SDL_HasAVX2"
		|| symName == "SDL_GetGlobalMouseState"
		|| symName == "SDL_WarpMouseGlobal"
		|| symName == "SDL_CaptureMouse"
		|| symName == "SDL_RenderIsClipEnabled"
		|| symName == "SDL_SetWindowHitTest") {
		return ShouldThrow.No;
	}

    // Any other missing symbol should throw.
    return ShouldThrow.Yes;
}

void initialize_systems() {

	import std.meta : AliasSeq;

	alias libs = AliasSeq!(
		DerelictSDL2, DerelictSDL2Image,
		DerelictSDL2ttf,DerelictFT,
		DerelictGL, DerelictAL,
		DerelictALURE, DerelictImgui);

	foreach (T; libs) {
		T.missingSymbolCallback = &missingSymFunc;
		T.load();
	}

	if (TTF_Init() == -1) {
		writefln("[GAME] TTF_Init: %s\n", TTF_GetError());
		exit(2);
	}

}

void main() {

	initialize_systems();

	auto game = NewGame();
	game.initialize();

	game.run();

}
