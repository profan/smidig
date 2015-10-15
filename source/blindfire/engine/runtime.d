module blindfire.engine.runtime;

import blindfire.engine.window : Window;
import blindfire.engine.eventhandler : EventHandler;
import blindfire.engine.render : IRenderer, OpenGLRenderer;
import blindfire.engine.event : EventManager, EventMemory;
import blindfire.engine.resource : ResourceManager;
import blindfire.engine.sound : SoundSystem;
import blindfire.engine.console : Console;
import blindfire.engine.net : NetworkPeer;

//probably belongs in the renderer itself later?
import blindfire.engine.gl : Cursor, FontAtlas;
import blindfire.engine.defs : DrawEventType, NetEventType;

enum Resource {
	BasicShader,
	TextShader,
	CursorTexture
} //Resource

struct Engine {

	import blindfire.engine.memory : allocatorObject, IAllocator, Mallocator, theAllocator, make;
	import blindfire.engine.dbg : DebugContext, render_string;
	import blindfire.engine.imgui : ImguiContext;

	alias UpdateFunc = void delegate();
	alias DrawFunc = void delegate();

	//defaults
	enum DEFAULT_WINDOW_WIDTH = 640, DEFAULT_WINDOW_HEIGHT = 480;
	enum MAX_SOUND_SOURCES = 32;

	//default allocator
	IAllocator allocator_;

	//common subsystems
	Window window_ = void;
	EventHandler input_handler_ = void;

	EventManager renderer_evman_ = void;
	IRenderer renderer_;

	EventManager network_evman_ = void;
	NetworkPeer network_ = void;

	SoundSystem sound_system_ = void;

	FontAtlas debug_atlas_ = void;
	Console console_ = void;
	Cursor cursor_ = void;

	DebugContext debug_context_ = void;
	ImguiContext imgui_context_ = void;

	//external references
	UpdateFunc update_function_;
	DrawFunc draw_function_;

	@disable this(this);

	void initialize(in char[] title, UpdateFunc update_func, DrawFunc draw_func) {

		import blindfire.engine.pool : construct;

		//allocator for shit
		this.allocator_ = theAllocator;

		//initialize window and input handler
		this.window_.construct(title, 640, 480);
		this.input_handler_.construct(allocator_);
		this.input_handler_.add_listener(&window_.handle_events);

		//initialize renderer and event manager for rendering events
		this.renderer_evman_.construct(EventMemory, DrawEventType.max);
		this.renderer_ = allocator_.make!OpenGLRenderer();

		//initialize network system and event manager for communication
		this.network_evman_.construct(EventMemory, NetEventType.max);
		this.network_.construct(cast(ushort)12000, &network_evman_);

		//initialize sound subsystem
		this.sound_system_.construct(allocator_, MAX_SOUND_SOURCES);
		this.sound_system_.initialize();

		//initialize console subsystem
		this.console_.construct(allocator_, &debug_atlas_, null);

		//initialize imgui context
		this.imgui_context_.construct(allocator_, &window_);
		this.imgui_context_.initialize();

		//link up imgui context to event shite
		import derelict.sdl2.types;
		this.input_handler_.add_listener(&imgui_context_.on_event,
			SDL_KEYDOWN, SDL_KEYUP, SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEWHEEL);

		//load engine-required resources
		this.load_resources();

		//set references
		this.update_function_ = update_func;
		this.draw_function_ = draw_func;

	} //initialize

	void load_resources() {

		import blindfire.engine.gl : AttribLocation, Shader, Texture;
		import blindfire.engine.pool : construct;
		import blindfire.engine.defs : Vec2i;

		auto rm = ResourceManager.get();

		//basic shader
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = allocator_.make!Shader("shaders/basic", attributes[], uniforms[]);
		rm.set_resource(shader, Resource.BasicShader);

		//text shader
		AttribLocation[1] text_attribs = [AttribLocation(0, "coord")];
		char[16][2] text_uniforms = ["color", "projection"];
		auto text_shader = allocator_.make!Shader("shaders/text", text_attribs[], text_uniforms[]); 
		rm.set_resource(text_shader, Resource.TextShader);

		//mouse pointer texture
		auto cursor_texture = allocator_.make!Texture("resource/img/other_cursor.png");
		rm.set_resource(cursor_texture, Resource.CursorTexture);
		this.cursor_.construct(cursor_texture, shader);

		//text atlases
		this.debug_atlas_.construct("fonts/OpenSans-Regular.ttf", 12, text_shader);
		this.debug_context_.construct(allocator_, &imgui_context_, &debug_atlas_, &window_, Vec2i(16, 32));

	} //load_resources

	void draw(double delta_time) {

		import blindfire.engine.math : Vec2f;

		window_.render_clear(0x428bca);

		draw_function_();

		bool show_another_window;

		import derelict.imgui.imgui;
		imgui_context_.new_frame(input_handler_, delta_time);
		igSetNextWindowSize(ImVec2(200,100), ImGuiSetCond_FirstUseEver);
		igBegin("Another Window", &show_another_window);

		{
			static float f = 0.0f;
			igText("Hello, world!");
			igSliderFloat("float", &f, 0.0f, 1.0f);
			igText("Application average %.3f ms/frame (%.1f FPS)", 1000.0f / igGetIO().Framerate, igGetIO().Framerate);
		}

		igEnd();

		imgui_context_.end_frame();

		draw_debug(delta_time);
		cursor_.draw(window_.view_projection, Vec2f(input_handler_.mouse_x, input_handler_.mouse_y));

		window_.render_present();


	} //draw

	void draw_debug(double delta_time) {

		import blindfire.engine.defs : Vec2i;
		import blindfire.engine.dbg : render_string;

		int x, y;
		input_handler_.mouse_pos(x, y);
		debug_context_.render_string!("update deltatime: %f")(update_time);
		debug_context_.render_string!("draw deltatime: %f")(delta_time);
		debug_context_.render_string!("framerate: %f")(1.0 / frame_time);
		debug_context_.render_string!("mouse x: %d, y: %d")(x, y);

		debug_context_.reset();

	} //draw_debug

	double update_time, frame_time, draw_time;

	void run() {

		import blindfire.engine.timer : StopWatch;

		static StopWatch main_timer, update_timer, draw_timer, frame_timer;
		static long iter, last_update, last_render;
		static long clock_ticks_per_second;

		iter = main_timer.ticks_per_second() / 60;
		clock_ticks_per_second = StopWatch.ticks_per_second();

		main_timer.start();
		update_timer.start();
		draw_timer.start();
		frame_timer.start();

		while (window_.is_alive) {

			if (main_timer.peek() - last_update > iter) {

				update_timer.start();

				//handle input
				this.input_handler_.handle_events();

				//update sound system
				this.sound_system_.tick();

				//update game and draw
				this.update_function_();
				update_time = cast(double)update_timer.peek() / cast(double)clock_ticks_per_second;
				last_update = main_timer.peek();
				update_timer.reset();

			}

			draw_timer.start();
			this.draw((draw_time > 0) ? draw_time : 1.0);
			draw_time = cast(double)draw_timer.peek() / cast(double)clock_ticks_per_second;
			frame_time = cast(double)frame_timer.peek() / cast(double)clock_ticks_per_second;
			last_render = draw_timer.peek();
			draw_timer.reset();
			frame_timer.reset();

		}


	} //run

	void step() {

	} //step

} //Engine