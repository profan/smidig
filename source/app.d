import std.stdio : writefln;
import std.c.process : exit;
import std.meta : AliasSeq;

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

ShouldThrow missingSymFunc( string symName ) {

	//introduced at a later version than what I can find as a binary on windows
	//also not used in the project, so lets not care about this dependency (gzip_uncompress)

	alias symbols = AliasSeq!(
		"FT_Gzip_Uncompress",
		"SDL_QueueAudio",
		"SDL_GetQueuedAudioSize",
		"SDL_ClearQueuedAudio",
		"SDL_HasAVX2",
		"SDL_GetGlobalMouseState",
		"SDL_WarpMouseGlobal",
		"SDL_CaptureMouse",
		"SDL_RenderIsClipEnabled",
		"SDL_SetWindowHitTest");

	foreach (sym; symbols) {
		if (symName == sym) return ShouldThrow.No;
	}

    // Any other missing symbol should throw.
    return ShouldThrow.Yes;
}

void initialize_systems() {

	alias libs = AliasSeq!(
		DerelictSDL2, DerelictSDL2Image,
		DerelictSDL2ttf, DerelictFT,
		DerelictGL, DerelictAL,
		DerelictALURE, DerelictImgui);

	foreach (T; libs) {
		T.missingSymbolCallback = &missingSymFunc;
		T.load();
	}

	//initiate SDL2 ttf
	if (TTF_Init() == -1) {
		writefln("[GAME] TTF_Init: %s\n", TTF_GetError());
		exit(2);
	}

}

void main() {

	import blindfire.game : NewGame;

	initialize_systems();

	auto game = NewGame();
	game.initialize();

	game.run();

}
