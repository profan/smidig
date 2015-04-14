module blindfire.util;

import blindfire.defs : Vec2i;
import blindfire.text : FontAtlas;
import blindfire.window : Window;

bool point_in_rect(int x, int y, int r_x, int r_y, int w, int h) {
	return (x < r_x + w && y < r_y + h && x > r_x && y > r_y);
}

void render_string(string format, Args...)(FontAtlas* atlas, Window* window, ref Vec2i offset, Args args) {
	render_string!(format)(*atlas, window, offset, args);
}

void render_string(string format, Args...)(ref FontAtlas atlas, Window* window, ref Vec2i offset, Args args) {

	import std.format : sformat;

	char[format.length*2] buf;
	const char[] str = sformat(buf, format, args);
	atlas.render_text(window, str, offset.x, offset.y, 1, 1, 0xffffff);
	offset.y += 16;

}
