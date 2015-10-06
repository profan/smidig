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

	FontAtlas debug_atlas = void;
	Console console = void;
	Cursor cursor = void;

	@disable this();
	@disable this(this);

	void initialize(in char[] title) {

		//allocator for shit
		this.allocator_ = theAllocator;

		//initialize window and input handler
		this.window_ = Window(title, 640, 480);
		this.input_handler_ = EventHandler.construct();

		//initialize renderer and event manager for rendering events
		this.renderer_evman_ = EventManager(EventMemory, DrawEventType.max);
		this.renderer_ = allocator_.make!OpenGLRenderer();

		//initialize network system and event manager for communication
		this.network_evman_ = EventManager(EventMemory, NetEventType.max);
		this.network_ = NetworkPeer(12000, &network_evman_);

		//initialize sound subsystem
		this.sound_system_ = SoundSystem(theAllocator, MAX_SOUND_SOURCES);
		this.sound_system_.initialize();

		//initialize console subsystem
		this.console = Console(&debug_atlas, null);

	} //initialize

	void load_resources() {

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
		this.cursor = Cursor(cursor_texture, shader);

		//text atlases
		this.debug_atlas = FontAtlas("fonts/OpenSans-Regular.ttf", 12, text_shader);

	} //load_resources

} //Engine