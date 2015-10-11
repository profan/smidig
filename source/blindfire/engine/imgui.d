module blindfire.engine.imgui;

import std.stdio : writefln;

import std.traits : isDelegate, ReturnType, ParameterTypeTuple;
auto bindDelegate(T, string file = __FILE__, size_t line = __LINE__)(T t) if(isDelegate!T) {

    static T dg;
	dg = t;

    extern(C)
		static ReturnType!T func(ParameterTypeTuple!T args) {
			return dg(args);
		}

	return &func;

} //bindDelegate (thanks Destructionator)

struct ImguiContext {

	import derelict.sdl2.types;
	import derelict.imgui.imgui;

	import blindfire.engine.gl : Shader, Texture;
	import blindfire.engine.eventhandler : AnyKey, EventHandler;

	Shader* vs_shader;
	Shader* fs_shader;
	Texture* font_texture;

	void initialize() {

		ImGuiIO* io = igGetIO();

		io.KeyMap[ImGuiKey_Tab] = SDL_SCANCODE_KP_TAB;
		io.KeyMap[ImGuiKey_LeftArrow] = SDL_SCANCODE_LEFT;
		io.KeyMap[ImGuiKey_RightArrow] = SDL_SCANCODE_RIGHT;
		io.KeyMap[ImGuiKey_UpArrow] = SDL_SCANCODE_UP;
		io.KeyMap[ImGuiKey_DownArrow] = SDL_SCANCODE_DOWN;
		io.KeyMap[ImGuiKey_Home] = SDL_SCANCODE_HOME;
		io.KeyMap[ImGuiKey_End] = SDL_SCANCODE_END;
		io.KeyMap[ImGuiKey_Delete] = SDL_SCANCODE_DELETE;
		io.KeyMap[ImGuiKey_Escape] = SDL_SCANCODE_ESCAPE;
		io.KeyMap[ImGuiKey_A] = SDL_SCANCODE_A;
		io.KeyMap[ImGuiKey_C] = SDL_SCANCODE_C;
		io.KeyMap[ImGuiKey_V] = SDL_SCANCODE_V;
		io.KeyMap[ImGuiKey_X] = SDL_SCANCODE_X;
		io.KeyMap[ImGuiKey_Y] = SDL_SCANCODE_Y;
		io.KeyMap[ImGuiKey_Z] = SDL_SCANCODE_Z;

		io.RenderDrawListsFn = bindDelegate(&render_draw_lists);
		io.SetClipboardTextFn = bindDelegate(&set_clipboard_text);
		io.GetClipboardTextFn = bindDelegate(&get_clipboard_text);

	} //initialize

	void on_event(ref SDL_Event ev) {

		writefln("got event: %s", ev.type);

		switch (ev.type) {

			case SDL_KEYDOWN, SDL_KEYUP:
				break;

			case SDL_MOUSEBUTTONDOWN:
				break;

			case SDL_MOUSEWHEEL:
				break;

			default:
				writefln("got other event: %s", ev.type);
				break;

		}

	} //on_event

	void render_draw_lists(ImDrawData* data) nothrow {

	} //render_draw_lists

	const(char*) get_clipboard_text() nothrow {

		import derelict.sdl2.functions : SDL_GetClipboardText;
		return SDL_GetClipboardText();

	} //get_clipboard_text

	void set_clipboard_text(const(char)* text) nothrow {

	} //set_clipboard_text

} //ImguiContext