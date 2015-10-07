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
import blindfire.engine.text : FontAtlas;
import blindfire.engine.gl : Cursor;

import blindfire.engine.defs : DrawEventType, NetEventType;

enum Resource {
	BasicShader,
	TextShader,
	CursorTexture
} //Resource

struct Engine {

	alias UpdateFunc = void delegate();
	alias DrawFunc = void delegate();

	//defaults
	enum DEFAULT_WINDOW_WIDTH = 640, DEFAULT_WINDOW_HEIGHT = 480;
	enum MAX_SOUND_SOURCES = 32;

	//default allocator
	import blindfire.engine.memory : IAllocator, theAllocator, make;
	IAllocator allocator_;

	//common state
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

	//external references
	UpdateFunc update_function_;
	DrawFunc draw_function_;

	@disable this(this);

	void initialize(in char[] title, UpdateFunc update_func) {

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
		this.sound_system_.construct(theAllocator, MAX_SOUND_SOURCES);
		this.sound_system_.initialize();

		//initialize console subsystem
		this.console_.construct(&debug_atlas_, null);

		//load engine-required resources
		this.load_resources();

		//set references
		this.update_function_ = update_func;

	} //initialize

	void load_resources() {

		import blindfire.engine.pool : construct;
		import blindfire.engine.gl : AttribLocation, Shader, Texture;

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

	} //load_resources

	void draw() {

		import blindfire.engine.defs : Vec2f;

		window_.render_clear(0x428bca);

		draw_debug();
		cursor_.draw(window_.view_projection, Vec2f(input_handler_.mouse_x, input_handler_.mouse_y));

		window_.render_present();

	} //draw

	void draw_debug() {

		import blindfire.engine.defs : Vec2i;
		import blindfire.engine.util : render_string;

		int x, y;
		input_handler_.mouse_pos(x, y);

		auto offset = Vec2i(16, 32);
		debug_atlas_.render_string!("mouse x: %d, y: %d")(&window_, offset, x, y);

	}

	void run() {

		import std.stdio : writefln;

		while (window_.is_alive) {

			//handle input
			this.input_handler_.handle_events();

			//update game and draw
			this.update_function_();
			this.draw();

		}

	} //run

	void step() {

	} //step

} //Engine