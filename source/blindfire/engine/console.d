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
		HashMap!(ConsoleCommand, CommandDelegate) commands_;

		FontAtlas* atlas_;
		ConsoleBuffer buffers_;
		ConsoleBuffer history_;

		bool enabled_ = false;
		size_t history_index_ = 0;
		size_t history_elements_ = 0;

	}

	//dependencies
	EventManager* evman;

	@disable this(this);

	this(IAllocator allocator, FontAtlas* font_atlas, EventManager* eventman) {

		import std.traits : EnumMembers;

		this.allocator_ = allocator;
		this.commands_ = typeof(commands_)(allocator_, 24);
		this.atlas_ = font_atlas;

		bind_command(ConsoleCommand.HELP,
			(Console* console, in char[] args) {
				foreach (i, field; EnumMembers!ConsoleCommand) console.print!(field);
				console.print!("Listing all commands_:");
		});

		this.evman = eventman;

	} //this

	void bind_command(ConsoleCommand cmd, CommandDelegate cd) {

		commands_[cmd] = cd;

	} //bind_command

	void print(string format, Args...)(Args args) {

		import blindfire.engine.util : cformat;

		char[128] fmt_str;
		const char[] c = cformat(fmt_str, format, args);
		write(c);
		shiftBuffer(buffers_);

	} //print

	void write(in char[] text) {

		import std.algorithm : min; //TODO remove
		size_t elements = buffers_[0].length;

		if (elements + text.length < BUFFER_WIDTH) {
			buffers_[0] ~= text;
		} else {
			size_t written = 0;
			while (written < text.length) {
				auto s = text[written .. min($, BUFFER_WIDTH-buffers_[0].length)];
				buffers_[0] ~= s;
				written += s.length;
				shiftBuffer(buffers_);
			}
		}

	} //write

	/* deletes last written character from input buffer */
	void del() {

		if (enabled_ && buffers_[0].length != 0) {
			 buffers_[0].length = buffers_[0].length - 1;
		}

	} //del

	/* toggles console */
	void toggle() {

		enabled_ = !enabled_;
		history_index_ = 0;
		(enabled_) ? SDL_StartTextInput() : SDL_StopTextInput();

	} //toggle

	/* interprets input in input buffer and tries to execute command */
	void run() {

		if (!enabled_) { return; }

		if (buffers_[0].length == 0) { return; }
		const char[] slice = buffers_[0][];

		uint i = 0;
		while (i != buffers_[0].length && slice[i] != ' ') {
			i++;
		}

		const char[] command = slice[0..i];

		size_t begin, end;
		if (i < buffers_[0].length) { begin = i+1; end = slice.length; }
		else { begin = i; end = i; }
		const char[] args = slice[begin .. end];

		auto found_command = cast(ConsoleCommand)command in commands_;
		if (found_command) {
			shiftBuffer(buffers_);
			(*found_command)(&this, args);
			history_[0] ~= slice;
			++history_elements_;
			shiftBuffer(history_);
		} else {
			shiftBuffer(buffers_);
			print!("Unknown Command: %s")(command.ptr);
		}
			
		history_index_ = 0;

	} //run

	/* go backwards in the command history_ */
	void getPrev() {

		if(!enabled_) { return; }

		if (history_index_ != 0)
			buffers_[0] = history_[--history_index_];

	} //getPrev

	/* go forwards in the command history_ */
	void getNext() {
		
		if(!enabled_) { return; }

		if (history_index_+1 < BUFFER_LINES && history_index_+1 <= history_elements_)
			buffers_[0] = history_[++history_index_];

	} //getNext

	/* shift lines out, making it circular */
	void shiftBuffer(ref ConsoleBuffer buf_to_shift) {

		for (int i = buf_to_shift.length-1; i >= 0; --i) {
			if (i == buf_to_shift.length -1) continue;
			buf_to_shift[i+1] = buf_to_shift[i];
			buf_to_shift[i].length = 0;
		}

	} //shiftBuffer

	void draw(Window* window) {

		if (!enabled_) { return; }

		int x = window.width - (atlas_.char_width * BUFFER_WIDTH) - atlas_.char_width, y = 16;
		int color = 0xFFFFFF;

		atlas_.renderText(window, ">", x, y + atlas_.char_height, 1, 1, color);
		atlas_.renderText(window, buffers_[0][], x + atlas_.char_width*2, y + atlas_.char_height, 1, 1, color);
		y += 12;
		foreach(ref buf; buffers_[1..$]) {

			if (buf.length != 0) {
				atlas_.renderText(window, buf[], x, y + atlas_.char_height, 1, 1, color);
			}
			y += 12;

		}
	
	} //draw
	
	void handleEvent(ref SDL_Event ev) {

		if (!enabled_) { return; }

		switch (ev.type) {
			case SDL_TEXTINPUT:
				write(ev.text.text[0..1]);
				break;
			default:
				
		}

	} //handleEvent

} //Console
