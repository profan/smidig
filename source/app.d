import core.stdc.stdio : printf;
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
import derelict.enet.enet;

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
		DerelictALURE, DerelictImgui,
		DerelictENet);

	foreach (T; libs) {
		T.missingSymbolCallback = &missingSymFunc;
		T.load();
	}

	if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) < 0) {
		printf("[GAME] SDL_Init, could not initialize: %s", SDL_GetError());
		exit(2);
	}

	//initiate SDL2 ttf
	if (TTF_Init() == -1) {
		printf("[GAME] TTF_Init: %s\n", TTF_GetError());
		exit(2);
	}

}

void main() {

	/* set up tracking shit */
	import std.experimental.allocator.gc_allocator : GCAllocator;
	import std.experimental.allocator.building_blocks.stats_collector : StatsCollector, Options;
	import blindfire.engine.memory : theAllocator, processAllocator, allocatorObject, Mallocator;

	alias Allocator = StatsCollector!(Mallocator, Options.all, Options.all);

	Allocator allocator;
	processAllocator = allocatorObject(&allocator);
	theAllocator = processAllocator;

	import std.stdio : stdout;
	scope(exit) allocator.reportStatistics(stdout);

	/* game part */
	import trackallocs;
	auto tracker = allocsTracker();
	import blindfire.game : NewGame;

	initialize_systems();

	auto game = NewGame();
	game.initialize();

	game.run();


}
