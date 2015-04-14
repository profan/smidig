module blindfire.graphics;

import std.stdio : writefln;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.opengl3.gl;

import blindfire.window : Window;
import blindfire.gl;

Texture create_font_texture(Window* window, in char* font_path, in char* font_text, int font_size, int font_color) {
	
	SDL_Color color = {cast(ubyte)(font_color>>16), cast(ubyte)(font_color>>8), cast(ubyte)(font_color)};
	TTF_Font* font = TTF_OpenFont(font_path, font_size);
	if (font == null) writefln("Error loading font, error : %s", TTF_GetError());
	SDL_Surface* surf = TTF_RenderUTF8_Blended(font, font_text, color);
	if (surf == null) writefln("Error rendering font, error : %s", TTF_GetError());
	Texture texture = Texture(surf.pixels, surf.w, surf.h, GL_RGBA, GL_RGBA);
	SDL_FreeSurface(surf);
	TTF_CloseFont(font);

	return texture;

}
