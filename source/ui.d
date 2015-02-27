module sundownstandoff.ui;

import derelict.sdl2.sdl;

import sundownstandoff.window;

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(Window* window, bool filled, int x, int y, int width, int height, int color, ubyte alpha = 255) {

	SDL_Rect rect = {x: x, y: y, w: width, h: height};

	//save draw color
	ubyte r,g,b,a;
	SDL_GetRenderDrawColor(window.renderer, &r, &g, &b, &a);

	SDL_SetRenderDrawColor(window.renderer, cast(ubyte)(color>>16), cast(ubyte)(color>>8), cast(ubyte)(color), alpha);
	(filled) ? SDL_RenderFillRect(window.renderer, &rect) : SDL_RenderDrawRect(window.renderer, &rect);

	//reset draw color
	SDL_SetRenderDrawColor(window.renderer, r, g, b, a);

}
