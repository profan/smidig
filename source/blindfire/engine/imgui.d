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
	import derelict.opengl3.gl;

	import blindfire.engine.gl : AttribLocation, Shader, Texture;
	import blindfire.engine.memory : theAllocator, IAllocator, make, dispose;
	import blindfire.engine.eventhandler : AnyKey, EventHandler;

	IAllocator allocator_;

	Shader* shader_;
	Texture* font_texture_;

	double time_;
	bool[3] mouse_buttons_pressed_;
	float scroll_wheel_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;

	} //this

	~this() {

		allocator_.dispose(shader_);
		allocator_.dispose(font_texture_);

	} //~this

	void initialize() {

		/* set the memory allocator */
		allocator_ = theAllocator;

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

		import std.stdio : writefln;

		auto io = igGetIO();

		switch (ev.type) {

			case SDL_KEYDOWN, SDL_KEYUP:
				io.KeysDown[ev.key.keysym.scancode] = (ev.type == SDL_KEYDOWN);
				break;

			case SDL_MOUSEBUTTONUP:
				if (ev.button.button < 4) {
					mouse_buttons_pressed_[ev.button.button-1] = true;
				}
				break;

			case SDL_MOUSEWHEEL:
				scroll_wheel_ += ev.wheel.y;
				break;

			default:
				writefln("unhandled event type in imgui: %d", ev.type);
				break;

		}

	} //on_event

	void create_device_objects() {

		AttribLocation[3] attrs = [
			AttribLocation(0, "Position"),
			AttribLocation(1, "UV"),
			AttribLocation(2, "Color")];

		char[16][2] uniforms = ["Texture", "ProjMtx"];
		shader_ = allocator_.make!Shader("shaders/imgui", attrs, uniforms);

	} //create_device_objects

	void create_font_texture() {

		auto io = igGetIO();

		ubyte* pixels;
		int width, height;
		ImFontAtlas_GetTexDataAsRGBA32(io.Fonts, &pixels, &width, &height, null);

		font_texture_ = allocator_.make!Texture(pixels, width, height, GL_RGBA, GL_RGBA);

	} //create_font_texture

	void render_draw_lists(ImDrawData* data) nothrow {

	} //render_draw_lists

	const(char*) get_clipboard_text() nothrow {

		import derelict.sdl2.functions : SDL_GetClipboardText;
		return SDL_GetClipboardText();

	} //get_clipboard_text

	void set_clipboard_text(const(char)* text) nothrow {

	} //set_clipboard_text

} //ImguiContext