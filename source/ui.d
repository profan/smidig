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

	uint active_item = 0, hot_item = 0;
	int mouse_x, mouse_y;
	uint mouse_buttons;

} //UIState

enum DrawFlags {

	NONE = 0,
	FILL = 1 << 0,
	BORDER = 1 << 1

} //RectangleType

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(Window* window, DrawFlags flags, int x, int y, int width, int height, int color, ubyte alpha = 255) {

	SDL_Rect rect = {x: x, y: y, w: width, h: height};
	auto p = PushColor(window, cast(ubyte)(color>>16), cast(ubyte)(color>>8), cast(ubyte)(color), alpha);
	(flags & DrawFlags.FILL) ? SDL_RenderFillRect(window.renderer, &rect) : SDL_RenderDrawRect(window.renderer, &rect);

}

void draw_label(Window* window, SDL_Texture* label, int x, int y, int width, int height, int padding) {
	SDL_Rect rect = {x: x+padding/2, y: y+padding/2, w: width-padding, h: height-padding};
	SDL_RenderCopy(window.renderer, label, null, &rect);
}

bool do_button(UIState* ui, uint id, Window* window, bool filled, int x, int y, int width, int height, int color, ubyte alpha = 255, SDL_Texture* label = null) {

	bool result = false;
	bool inside = point_in_rect(ui.mouse_x, ui.mouse_y, x - width/2, y - height/2, width, height);

	if (inside) ui.hot_item = id;

	if (ui.active_item == id && !is_btn_down(ui, 1)) {
		if (inside) {
			result = true;
		} else {
			ui.hot_item = 0;
		}
		ui.active_item = 0;
	} else if (ui.hot_item == id) {
		if (ui.active_item == 0 && is_btn_down(ui, 1)) {
			ui.active_item = id;
		}
	}

	draw_rectangle(window, (filled) ? DrawFlags.FILL : DrawFlags.NONE, x - width/2, y - height/2, width, height, color, alpha);
	if (label != null) draw_label(window, label, x - width/2, y - height/2, width, height, 4);

	return result;

}

bool is_btn_down(UIState* ui, uint button) {
	return (ui.mouse_buttons >> button-1) & 1;
}
