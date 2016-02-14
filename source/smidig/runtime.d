module smidig.runtime;

import smidig.window : Window;
import smidig.input : InputHandler;
import smidig.net : initializeEnet, NetworkManager;
import smidig.event : EventManager, EventMemory;
import smidig.resource : ResourceManager;
import smidig.sound : SoundSystem;

//probably belongs in the renderer itself later?
import smidig.gl : Cursor, FontAtlas;
import smidig.defs : DrawEventType, NetEventType;
import smidig.utils.console : Console;

enum Resource {
	TextShader
} //Resource

struct Engine {

	/**
	 * Type returned on creation.
	*/
	enum Error {
		WindowInitFailed,
		SoundInitFailed,
		NetInitFailed,
		Success
	} //Error

	import smidig.cpu : CPU;
	import smidig.memory : IAllocator, Mallocator, theAllocator, make;
	import smidig.dbg : DebugContext, render_string;
	import smidig.types : visit, Nullable, Result;
	import smidig.imgui : ImguiContext;
	import smidig.gl : RenderTarget;

	alias UpdateFunc = void delegate();
	alias DrawFunc = void delegate(double);
	alias RunFunc = void delegate();

	//defaults
	enum DEFAULT_WINDOW_WIDTH = 640;
	enum DEFAULT_WINDOW_HEIGHT = 480;
	enum MAX_SOUND_SOURCES = 32;

	//default allocator
	IAllocator allocator_;

	//common subsystems
	Window window_ = void;
	InputHandler input_handler_ = void;

	EventManager network_evman_ = void;
	NetworkManager network_manager_ = void;

	SoundSystem sound_system_ = void;

	FontAtlas debug_atlas_ = void;

	DebugContext debug_context_ = void;
	ImguiContext imgui_context_ = void;

	//time-related metrics
	double update_time_;
	double frame_time_;
	double draw_time_;

	double time_since_last_update_;

	//update rate
	int update_rate_ = 30;
	int draw_rate_ = 60;

	//external references
	UpdateFunc update_function_;
	DrawFunc draw_function_, after_draw_function_;
	RunFunc run_function_;

	@disable this(this);

	@property {

		ref FontAtlas atlas() { return debug_atlas_; }
		ref RenderTarget view() { return window_.render_target_; }

		int update_rate(int new_update_rate) { return update_rate_ = new_update_rate; }
		int update_rate() const { return update_rate_; }

		int draw_rate(int new_draw_rate) { return draw_rate_ = new_draw_rate; }
		int draw_rate() const { return draw_rate_; }

	}

	static Error create(ref Engine engine, in char[] title, UpdateFunc update_func, DrawFunc draw_func, DrawFunc after_draw_func) {

		import derelict.sdl2.types;
		import std.stdio : writefln;
		import smidig.memory : construct;
		import smidig.defs : PushEvent;

		with (engine) {

			//initialize dynamic dependencies
			import smidig.deps : initializeSystems;
			initializeSystems();

			//allocator for shit
			allocator_ = theAllocator;

			//report supported cpu characteristics
			CPU.report_supported();

			//initialize window and input handler
			auto result = Window.create(window_, title, 640, 480);
			final switch (result) with (Window.Error) {
				case RendererCreationFailed, ContextCreationFailed:
					return Error.WindowInitFailed;
				case Success:
					break;
			}

			input_handler_.construct(allocator_);
			input_handler_.addListener(&window_.handleEvents, SDL_WINDOWEVENT, SDL_QUIT);

			//initialize networking subsystem
			network_evman_.construct(EventMemory, NetEventType.max);
			network_manager_.construct(allocator_, &network_evman_);
			network_evman_.register!PushEvent(&network_manager_.onDataPush);
			initializeEnet();

			//initialize sound subsystem
			auto sound_result = SoundSystem.create(sound_system_, allocator_, MAX_SOUND_SOURCES);
			final switch (sound_result) with (SoundSystem.Error) {
				case FailedOpeningDevice, FailedCreatingContext, FailedMakingContextCurrent:
					return Error.SoundInitFailed;
				case Success:
					break;
			}

			//initialize imgui context
			imgui_context_.construct(allocator_, &window_, &input_handler_);
			imgui_context_.initialize();

			//link up imgui context to event shite
			input_handler_.addListener(&imgui_context_.onEvent,
				SDL_KEYDOWN, SDL_KEYUP, SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP, SDL_MOUSEWHEEL, SDL_TEXTINPUT);

			//load engine-required resources
			loadResources();

			//set userspace references
			update_function_ = update_func;
			draw_function_ = draw_func;
			after_draw_function_ = after_draw_func;

		} //with

		return Error.Success;

	} //initialize

	void loadResources() {

		import smidig.gl : AttribLocation, Shader, Texture;
		import smidig.memory : construct;
		import smidig.defs : Vec2i;

		auto rm = ResourceManager.get();

		//text shader
		AttribLocation[1] text_attribs = [AttribLocation(0, "coord")];
		char[16][2] text_uniforms = ["color", "projection"];
		auto text_shader = allocator_.make!Shader("shaders/text", text_attribs[], text_uniforms[]); 
		rm.setResource(text_shader, Resource.TextShader);

		//text atlases
		this.debug_atlas_.construct("fonts/OpenSans-Regular.ttf", 12, text_shader);
		this.debug_context_.construct(allocator_, &imgui_context_, &debug_atlas_, &window_, Vec2i(16, 32));

	} //loadResources

	void draw(double delta_time, double update_dt) {

		import smidig.math : Vec2f;

		window_.renderClear(0x428bca);

		draw_function_(update_dt);
		draw_debug(update_dt);
		imgui_context_.endFrame();
		after_draw_function_(update_dt);

		window_.renderPresent();

	} //draw

	void draw_debug(double delta_time) {

		import smidig.defs : Vec2i;
		import smidig.dbg : render_string;

		int x, y;
		input_handler_.mouse_pos(x, y);

		debug_context_
			.render_string!("last update deltatime: %f")(time_since_last_update_)
			.render_string!("update deltatime: %f")(update_time_)
			.render_string!("draw deltatime: %f")(draw_time_)
			.render_string!("framerate: %f")(1.0 / frame_time_);

		debug_context_.reset();


	} //draw_debug

	void run() {

		import smidig.timer : StopWatch;

		static StopWatch main_timer, update_timer, draw_timer, frame_timer;
		static long update_iter, draw_iter, last_update, last_render;
		static long clock_ticks_per_second;

		clock_ticks_per_second = StopWatch.ticksPerSecond();

		main_timer.start();
		update_timer.start();
		draw_timer.start();
		frame_timer.start();

		imgui_context_.newFrame((frame_time_) > 0 ? frame_time_ : 1.0);

		while (window_.is_alive) {

			update_iter = clock_ticks_per_second / update_rate_;
			draw_iter = clock_ticks_per_second / draw_rate_;

			if (main_timer.peek() - last_update > update_iter) {

				import smidig.event : Event;
				import smidig.defs;
				mixin EventManager.doTick;

				update_timer.start();
				imgui_context_.newFrame((update_time_) > 0 ? update_time_ : 1.0);

				import derelict.imgui.imgui : igSliderInt;
				igSliderInt("update rate", &update_rate_, 1, 800);
				igSliderInt("draw rate", &draw_rate_, 1, 800);

				//handle input
				this.input_handler_.handleEvents();

				//update sound system
				this.sound_system_.tick();

				//update game and draw
				this.update_function_();

				//poll for network updates
				this.network_manager_.poll();
				tick!NetEventIdentifier(network_evman_);

				update_time_ = cast(double)update_timer.peek() / cast(double)clock_ticks_per_second;
				last_update = main_timer.peek();
				update_timer.reset();

			}

			auto ticks_since_last_update = main_timer.peek() - last_update;
			time_since_last_update_ = (cast(double)ticks_since_last_update / cast(double)clock_ticks_per_second)
				/ (cast(double)update_iter / cast(double)clock_ticks_per_second);

			draw_timer.start();
			this.draw((draw_time_ > 0) ? draw_time_ : 1.0, time_since_last_update_);
			draw_time_ = cast(double)draw_timer.peek() / cast(double)clock_ticks_per_second;
			last_render = draw_timer.peek();
			draw_timer.reset();

			import smidig.timer : delayMs;
			uint frame_ms = cast(uint)((cast(real)frame_timer.peek() / cast(real)clock_ticks_per_second) * 1000);
			uint wanted_time = cast(uint)((cast(real)draw_iter / cast(real)clock_ticks_per_second) * 1000);
			uint wait_time = wanted_time - frame_ms;

			auto t = (wait_time < wanted_time) ? wait_time : wanted_time;
			delayMs((t > 0) ? t-1 : 0);
			frame_time_ = cast(double)frame_timer.peek() / cast(double)clock_ticks_per_second;
			frame_timer.reset();

		}


	} //run

} //Engine
