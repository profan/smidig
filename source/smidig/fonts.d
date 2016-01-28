module smidig.fonts;

import core.stdc.stdio : printf;

import derelict.sdl2.sdl;
import derelict.sdl2.ttf;
import derelict.opengl3.gl;

import smidig.gl;

Texture createFontTexture(in char* font_path, in char* font_text, int font_size, int font_color) {

	SDL_Color color = {cast(ubyte)(font_color>>16), cast(ubyte)(font_color>>8), cast(ubyte)(font_color)};

	TTF_Font* font = TTF_OpenFont(font_path, font_size);
	if (font == null) {
		printf("Error loading font, error : %s \n", TTF_GetError());
	}

	SDL_Surface* surf = TTF_RenderUTF8_Blended(font, font_text, color);
	if (surf == null) {
		printf("Error rendering font, error : %s \n", TTF_GetError());
	}

	Texture texture = Texture(surf.pixels, surf.w, surf.h, GL_RGBA, GL_RGBA);

	SDL_FreeSurface(surf);
	TTF_CloseFont(font);

	return texture;

} //createFontTexture
