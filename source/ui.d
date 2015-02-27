module sundownstandoff.ui;

import derelict.sdl2.sdl;

import sundownstandoff.window;

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(Window* window, int x, int y, int width, int height, int color) {
	SDL_Rect rect = {x: x, y: y, w: width, h: height};
	Uint8 r,g,b,a;
	SDL_GetRenderDrawColor(window.renderer, &r, &g, &b, &a);
	SDL_SetRenderDrawColor(window.renderer, cast(Uint8)(color>>24), cast(Uint8)(color>>16), cast(Uint8)(color>>8), cast(Uint8)color);
	SDL_RenderDrawRect(window.renderer, &rect);
	SDL_SetRenderDrawColor(window.renderer, r, g, b, a);
}
