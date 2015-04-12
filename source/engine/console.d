module blindfire.console;

import std.stdio : writefln;
import derelict.sdl2.sdl;

import blindfire.text : FontAtlas;
import blindfire.window : Window;

import profan.collections : StaticArray;

enum ConsoleCommand {

	SET_TICKRATE = "set_tickrate"

}

alias void delegate(in char[] arguments) CommandDelegate;

struct Console {

	enum BUFFER_WIDTH = 80;
	enum BUFFER_LINES = 30;

	FontAtlas* atlas;
	bool enabled = false;
	StaticArray!(char, BUFFER_WIDTH)[BUFFER_LINES] buffers;
	
	CommandDelegate[ConsoleCommand] commands;
	ubyte[4] pad;

	this(FontAtlas* font_atlas) {
		this.atlas = font_atlas;
	}

	void bind_command(ConsoleCommand cmd, CommandDelegate cd) {

		commands[cmd] = cd;

	}

	void print(in char[] text) {
		buffers[0] ~= cast(char[])text;
		shift_buffer();
	}

	void write(in char[] text) {

		if (buffers[0].elements + text.length < BUFFER_WIDTH) {
			buffers[0] ~= cast(char[])text;
		} else {
			shift_buffer();
			buffers[0] ~= cast(char[])text;
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

		if (buffers[0].elements == 0) return;
		const char[] slice = buffers[0][0..buffers[0].elements];

		uint i = 0;
		while (slice[i++] != ' ') {
			if (i == buffers[0].elements) {
				shift_buffer();
				print("Unknown Command!"); 
				return; 
			}
		}

		const char[] command = slice[0..i-1];
		const char[] args = slice[i .. $];

		if (command in commands) {
			commands[command](args);
			shift_buffer();
		} else {
			shift_buffer();
			print("Unknown Command!");
		}

	}

	void shift_buffer() {

		for (int i = buffers.length-1; i >= 0; --i) {
			if (i == buffers.length -1) continue;
			buffers[i+1] = buffers[i];
			buffers[i].elements = 0;
		}

	}

	import blindfire.ui : UIState, DrawFlags, draw_rectangle;
	void draw(Window* window, UIState* state) {

		if (!enabled) return;

		int x = window.width - (atlas.char_width * BUFFER_WIDTH) - atlas.char_width, y = 32;
		int color = 0xFFFFFF;

		draw_rectangle(window, state, DrawFlags.FILL, x - atlas.char_width, y - atlas.char_height - 4, atlas.char_width * BUFFER_WIDTH, 16, 0x000000, 125);

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
