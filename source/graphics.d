module sundownstandoff.graphics;

import std.stdio : writefln;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;

import sundownstandoff.window;

SDL_Texture* create_font_texture(Window* window, immutable char* font_path, immutable char* font_text, int font_size, int font_color) {
	
	SDL_Texture* texture;

	SDL_Color color = {cast(ubyte)(font_color<<16), cast(ubyte)(font_color<<8), cast(ubyte)(font_color)};
	TTF_Font* font = TTF_OpenFont(font_path, font_size);
	if (font == null) writefln("Error loading font, error : %s", TTF_GetError());
	SDL_Surface* surf = TTF_RenderUTF8_Blended(font, font_text, color);
	if (surf == null) writefln("Error rendering font, error : %s", TTF_GetError());
	texture = SDL_CreateTextureFromSurface(window.renderer, surf);
	SDL_FreeSurface(surf);

	return texture;

}
