module blindfire.console;

import std.stdio : writefln;
import derelict.sdl2.sdl;

import blindfire.text : FontAtlas;
import blindfire.window : Window;

import profan.collections : StaticArray;

enum ConsoleCommand {

	HELP = "help",
	LIST_COMMANDS = "list_commands",
	SET_TICKRATE = "set_tickrate",
	PUSH_STATE = "push_state"

}

alias void delegate(in char[] arguments) CommandDelegate;

struct Console {

	enum BUFFER_WIDTH = 80;
	enum BUFFER_LINES = 30;

	alias StaticArray!(char, BUFFER_WIDTH)[BUFFER_LINES] ConsoleBuffer;

	FontAtlas* atlas;
	bool enabled = false;
	ConsoleBuffer buffers;
	ConsoleBuffer history;
	
	CommandDelegate[ConsoleCommand] commands;

	this(FontAtlas* font_atlas) {
		this.atlas = font_atlas;

		import std.traits : EnumMembers;
		bind_command(ConsoleCommand.HELP,
			(in char[] args) {
				foreach (i, field; EnumMembers!ConsoleCommand) print!(field);
				print!("Listing all commands:");
		});

	}

	void bind_command(ConsoleCommand cmd, CommandDelegate cd) {

		commands[cmd] = cd;

	}

	void print(string format, Args...)(Args args) {
		import std.format : sformat;
		char[128] fmt_str;
		char[] c = sformat(fmt_str, format, args);
		buffers[0] ~= c;
		shift_buffer(buffers);
	}

	void write(in char[] text) {

		if (buffers[0].elements + text.length < BUFFER_WIDTH) {
			buffers[0] ~= text;
		} else {
			shift_buffer(buffers);
			buffers[0] ~= text;
		}

	}

	void del() {

		if (enabled && buffers[0].elements != 0) {
			 buffers[0].elements--;
		}

	}

	void toggle() {

		enabled = !enabled;
		history_index = 0;
		(enabled) ? SDL_StartTextInput() : SDL_StopTextInput();

	}

	void run() {

		if (!enabled) return;

		if (buffers[0].elements == 0) return;
		const char[] slice = buffers[0][0..buffers[0].elements];

		uint i = 0;
		while (i != buffers[0].elements && slice[i] != ' ') {
			i++;
		}

		const char[] command = slice[0..i];

		size_t begin, end;
		if (i < buffers[0].elements) { begin = i+1; end = slice.length; }
		else { begin = i; end = i; }
		const char[] args = slice[begin .. end];

		if (command in commands) {
			shift_buffer(buffers);
			commands[command](args);
			history[0] ~= slice;
			++history_elements;
			shift_buffer(history);
		} else {
			shift_buffer(buffers);
			print!("Unknown Command: %s")(command);
		}
			
		history_index = 0;

	}

	size_t history_index = 0;
	size_t history_elements = 0;
	ubyte[4] pad;
	void get_prev() {

		if(!enabled) return;
		if (history_index != 0)
			buffers[0] = history[--history_index];

	}

	void get_next() {
		
		if(!enabled) return;
		if (history_index+1 < BUFFER_LINES && history_index+1 <= history_elements)
			buffers[0] = history[++history_index];

	}

	void shift_buffer(ref ConsoleBuffer buf_to_shift) {

		for (int i = buf_to_shift.length-1; i >= 0; --i) {
			if (i == buf_to_shift.length -1) continue;
			buf_to_shift[i+1] = buf_to_shift[i];
			buf_to_shift[i].elements = 0;
		}

	}

	void draw(Window* window) {

		if (!enabled) return;

		int x = window.width - (atlas.char_width * BUFFER_WIDTH) - atlas.char_width, y = 16;
		int color = 0xFFFFFF;

		atlas.render_text(window, ">", x, y + atlas.char_height, 1, 1, color);
		atlas.render_text(window, buffers[0][0..buffers[0].elements], x + atlas.char_width*2, y + atlas.char_height, 1, 1, color);
		y += 12;
		foreach(ref buf; buffers[1..$]) {

			if (buf.elements != 0) {
				atlas.render_text(window, buf[0..buf.elements], x, y + atlas.char_height, 1, 1, color);
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
