module blindfire.console;

import std.stdio : writefln;
import derelict.sdl2.sdl;

import blindfire.text : FontAtlas;
import blindfire.window : Window;

import profan.collections : StaticArray;

enum ConsoleCommand {

	SET_FPS = "set_fps"

}

struct Console {

	enum BUFFER_WIDTH = 80;
	enum BUFFER_LINES = 30;

	bool enabled = false;
	FontAtlas* atlas;
	StaticArray!(char, BUFFER_WIDTH)[BUFFER_LINES] buffers;

	this(FontAtlas* font_atlas) {
		this.atlas = font_atlas;
	}

	void write(char[] text) {

		if (buffers[0].elements + text.length < BUFFER_WIDTH) {
			buffers[0] ~= text;
		} else {
			
		}

	}

	void del() {

		if (enabled && buffers[0].elements != 0) {
			 buffers[0].elements--;
		}

	}

	void toggle() {

		enabled = !enabled;
		(enabled) ? SDL_StartTextInput() : SDL_StopTextInput();

	}

	void run() {

		if (!enabled) return;

		const char[] slice = buffers[0][0..buffers[0].elements];
		switch (slice) {

			case ConsoleCommand.SET_FPS:
				writefln("[Console] Set FPS!");
				break;
				
			default:
				writefln("[Console] Unknown command: %s", slice);

		}

	}

	void draw(Window* window) {

		if (!enabled) return;

		int x = window.width - (atlas.char_width * BUFFER_WIDTH) - atlas.char_width, y = 32;
		int color = 0xFFFFFF;	

		foreach(ref buf; buffers) {

			if (buf.elements != 0) {
				atlas.render_text(window, buf[0..buf.elements], x, y, 1, 1, color);
			}
			y += 12;

		}
	
	}
	
	void handle_event(ref SDL_Event ev) {

		if (!enabled) return;

		switch (ev.type) {
			case SDL_TEXTINPUT:
				write(ev.text.text[0..1]);
				break;
			default:
				
		}

	}

} //Console
