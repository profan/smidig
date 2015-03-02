module sundownstandoff.ui;

import derelict.sdl2.sdl;

import sundownstandoff.window;
import sundownstandoff.util;

struct PushColor {

	Window* window;
	ubyte r, g, b, a;

	this(Window* window, ubyte r, ubyte g, ubyte b, ubyte a) {
		this.window = window;
		SDL_GetRenderDrawColor(window.renderer, &this.r, &this.g, &this.b, &this.a);
		SDL_SetRenderDrawColor(window.renderer, r, g, b, a);
	}

	~this() {
		SDL_SetRenderDrawColor(window.renderer, r, g, b, a);
	}

} //PushColor

struct UIState {

	int mouse_x, mouse_y;

} //UIState

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(Window* window, bool filled, int x, int y, int width, int height, int color, ubyte alpha = 255) {

	SDL_Rect rect = {x: x, y: y, w: width, h: height};
	auto p = PushColor(window, cast(ubyte)(color>>16), cast(ubyte)(color>>8), cast(ubyte)(color), alpha);
	(filled) ? SDL_RenderFillRect(window.renderer, &rect) : SDL_RenderDrawRect(window.renderer, &rect);

}

bool do_button(UIState* ui, Window* window, bool filled, int x, int y, int width, int height, int color, ubyte alpha = 255) {

	draw_rectangle(window, filled, x - width/2, y - height/2, width, height, color, alpha);
	return point_in_rect(ui.mouse_x, ui.mouse_y, x - width/2, y - height/2, width, height);

}
