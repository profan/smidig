module sundownstandoff.action;

import sundownstandoff.ui : draw_rectangle, DrawFlags;
import sundownstandoff.window : Window;
import sundownstandoff.sys : Vec2f;

import std.stdio : writefln;


struct SelectionBox {

	bool active = false, order_set = false;
	int x = 0, y = 0;
	int w = 0, h = 0;
	int to_x = 0, to_y = 0;

	void set_order(int new_x, int new_y) {
		order_set = true;
		to_x = new_x;
		to_y = new_y;
	}

	void set_size(int new_w, int new_h) {
		w = new_w - x;
		h = new_h - y;
	}

	void set_active(int start_x, int start_y) {
		x = start_x;
		y = start_y;
		w = 0; h = 0;
		active = true;
	}

	void set_inactive(int x, int y) {
		w = 0;
		h = 0;
		active = false;
	}

	void draw(Window* window) {

		if (active) {
			draw_rectangle(window, DrawFlags.FILL, x, y, w, h, 0x428bca);
		}
		
		order_set = false;

	}

} //SelectionBox
