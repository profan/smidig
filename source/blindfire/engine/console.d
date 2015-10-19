module blindfire.engine.console;

import derelict.sdl2.types : SDL_Event, SDL_TEXTINPUT;
import derelict.sdl2.functions : SDL_StartTextInput, SDL_StopTextInput;

import blindfire.engine.memory : IAllocator;
import blindfire.engine.collections : HashMap, StaticArray;
import blindfire.engine.event : EventManager, EventCast;
import blindfire.engine.window : Window;
import blindfire.engine.gl : FontAtlas;

enum ConsoleCommand {

	HELP = "help",
	SET_TICKRATE = "set_tickrate",
	PUSH_STATE = "push_state"

} //ConsoleCommand FIXME should this really be here?

alias void delegate(Console* console, in char[] arguments) CommandDelegate;

struct Console {

	private {

		enum BUFFER_WIDTH = 80;
		enum BUFFER_LINES = 30;

		/* reference to allocator used */
		IAllocator allocator_;

		alias StaticArray!(char, BUFFER_WIDTH)[BUFFER_LINES] ConsoleBuffer;
		HashMap!(ConsoleCommand, CommandDelegate) commands;

		FontAtlas* atlas;
		ConsoleBuffer buffers;
		ConsoleBuffer history;

		bool enabled = false;
		size_t history_index = 0;
		size_t history_elements = 0;


	}

	//dependencies
	EventManager* evman;

	@disable this(this);

	this(IAllocator allocator, FontAtlas* font_atlas, EventManager* eventman) {

		import std.traits : EnumMembers;

		this.allocator_ = allocator;
		this.commands = typeof(commands)(allocator_, 24);
		this.atlas = font_atlas;

		bind_command(ConsoleCommand.HELP,
			(Console* console, in char[] args) {
				foreach (i, field; EnumMembers!ConsoleCommand) console.print!(field);
				console.print!("Listing all commands:");
		});

		this.evman = eventman;

	} //this

	void bind_command(ConsoleCommand cmd, CommandDelegate cd) {

		commands[cmd] = cd;

	} //bind_command

	void print(string format, Args...)(Args args) {

		import blindfire.engine.util : cformat;

		char[128] fmt_str;
		const char[] c = cformat(fmt_str, format, args);
		write(c);
		shift_buffer(buffers);

	} //print

	void write(in char[] text) {

		import std.algorithm : min; //TODO remove
		size_t elements = buffers[0].length;

		if (elements + text.length < BUFFER_WIDTH) {
			buffers[0] ~= text;
		} else {
			size_t written = 0;
			while (written < text.length) {
				auto s = text[written .. min($, BUFFER_WIDTH-buffers[0].length)];
				buffers[0] ~= s;
				written += s.length;
				shift_buffer(buffers);
			}
		}

	} //write

	/* deletes last written character from input buffer */
	void del() {

		if (enabled && buffers[0].length != 0) {
			 buffers[0].length = buffers[0].length - 1;
		}

	} //del

	/* toggles console */
	void toggle() {

		enabled = !enabled;
		history_index = 0;
		(enabled) ? SDL_StartTextInput() : SDL_StopTextInput();

	} //toggle

	/* interprets input in input buffer and tries to execute command */
	void run() {

		if (!enabled) { return; }

		if (buffers[0].length == 0) { return; }
		const char[] slice = buffers[0][];

		uint i = 0;
		while (i != buffers[0].length && slice[i] != ' ') {
			i++;
		}

		const char[] command = slice[0..i];

		size_t begin, end;
		if (i < buffers[0].length) { begin = i+1; end = slice.length; }
		else { begin = i; end = i; }
		const char[] args = slice[begin .. end];

		auto found_command = cast(ConsoleCommand)command in commands;
		if (found_command) {
			shift_buffer(buffers);
			(*found_command)(&this, args);
			history[0] ~= slice;
			++history_elements;
			shift_buffer(history);
		} else {
			shift_buffer(buffers);
			print!("Unknown Command: %s")(command.ptr);
		}
			
		history_index = 0;

	} //run

	/* go backwards in the command history */
	void get_prev() {

		if(!enabled) { return; }

		if (history_index != 0)
			buffers[0] = history[--history_index];

	} //get_prev

	/* go forwards in the command history */
	void get_next() {
		
		if(!enabled) { return; }

		if (history_index+1 < BUFFER_LINES && history_index+1 <= history_elements)
			buffers[0] = history[++history_index];

	} //get_next

	/* shift lines out, making it circular */
	void shift_buffer(ref ConsoleBuffer buf_to_shift) {

		for (int i = buf_to_shift.length-1; i >= 0; --i) {
			if (i == buf_to_shift.length -1) continue;
			buf_to_shift[i+1] = buf_to_shift[i];
			buf_to_shift[i].length = 0;
		}

	} //shift_buffer

	void draw(Window* window) {

		if (!enabled) { return; }

		int x = window.width - (atlas.char_width * BUFFER_WIDTH) - atlas.char_width, y = 16;
		int color = 0xFFFFFF;

		atlas.render_text(window, ">", x, y + atlas.char_height, 1, 1, color);
		atlas.render_text(window, buffers[0][], x + atlas.char_width*2, y + atlas.char_height, 1, 1, color);
		y += 12;
		foreach(ref buf; buffers[1..$]) {

			if (buf.length != 0) {
				atlas.render_text(window, buf[], x, y + atlas.char_height, 1, 1, color);
			}
			y += 12;

		}
	
	} //draw
	
	void handle_event(ref SDL_Event ev) {

		if (!enabled) { return; }

		switch (ev.type) {
			case SDL_TEXTINPUT:
				write(ev.text.text[0..1]);
				break;
			default:
				
		}

	} //handle_event

} //Console
