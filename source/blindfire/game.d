module blindfire.game;

import derelict.sdl2.sdl;

import blindfire.engine.input : KeyState;
import blindfire.engine.util : render_string;
import blindfire.engine.resource;
import blindfire.engine.event;
import blindfire.engine.defs;

import blindfire.graphics;
import blindfire.defs;
import blindfire.ui;

struct Game {

	import blindfire.engine.memory : make, construct;
	import blindfire.engine.sound : SoundID;
	import blindfire.engine.runtime;
	import blindfire.engine.ecs;
	import blindfire.engine.gl;

	import blindfire.engine.utils.joy;
	import blindfire.engine.utils.profiler : Profiler;

	import blindfire.chat;
	import blindfire.sys;

	enum GameResource : ResourceID {
		Click = Resource.max+1,
		BasicShader,
		CursorTexture
	} //GameResource

	private {

		//engine parts
		Engine engine_;

		//test game systems
		Chat chat_ = void;
	
		//resource cursor
		Cursor cursor_ = void;

		//profiler
		Profiler profiler_ = void;

		//visualizing joystick shit
		JoyVisualizer visualizer_ = void;

		//game test
		EventManager event_manager_ = void;
		EntityManager entity_manager_;

		//temporary junk TODO remove
		TestParticleSystem particle_system_ = void;

	}

	@disable this(this);

	void initialize() {

		//initialize engine systems
		this.engine_.initialize("Project Blindfire", &update, &draw, &lastDraw);

		//initialize self
		initializeSystems();
		loadResources();
		bindActions();

	} //initialize

	void initializeSystems() {

		auto ea = engine_.allocator_;

		//create chat, registers events too
		this.chat_.construct(ea, &engine_.network_evman_);

		this.profiler_.construct(ea);
		this.visualizer_.construct(&engine_.input_handler_);

		//game test
		this.event_manager_.construct(EventMemory, EventType.max);
		this.entity_manager_ = ea.make!EntityManager(engine_.allocator_);

		//systems
		auto t_man = this.entity_manager_.registerSystem!TransformManager();
		this.entity_manager_.registerSystem!CollisionManager(Vec2i(640, 480));
		this.entity_manager_.registerSystem!SpriteManager();

		event_manager_.register!AnalogAxisEvent(&t_man.onAnalogMovement);
		event_manager_.register!AnalogRotEvent(&t_man.onAnalogRotation);

		//tmp
		this.particle_system_.construct(ea, 0);
		particle_system_.config(Vec2f(0, 0), 16.0f, 512);

	} //initializeSystems

	void loadResources() {

		import blindfire.engine.gl : AttribLocation, Shader, Texture;
		import blindfire.engine.memory : make;

		auto rm = ResourceManager.get();
		auto ea = engine_.allocator_;

		//load click sound
		auto click_file = engine_.sound_system_.loadSoundFile(cast(char*)"resource/audio/radiy_click.wav".ptr);
		rm.setResource!(SoundID)(cast(SoundID*)click_file, GameResource.Click);

		//basic shader
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = ea.make!Shader("shaders/basic", attributes[], uniforms[]);
		rm.setResource(shader, GameResource.BasicShader);

		//mouse pointer texture
		auto cursor_texture = ea.make!Texture("resource/img/other_cursor.png");
		rm.setResource(cursor_texture, GameResource.CursorTexture);
		this.cursor_.construct(cursor_texture, shader);

		//create unit
		import blindfire.ents : createUnit;
		auto unit = createUnit(entity_manager_, Vec2f(320, 240), shader, cursor_texture);

		//GC's GOTTA GC
		void onAxis(int value) {
			event_manager_.push!AnalogAxisEvent(AxisPayload(unit, value));
		} //on_axis

		void onRotAxis(int value) {
			event_manager_.push!AnalogRotEvent(AxisPayload(unit, value));
		} //on_rot_axis

		engine_.input_handler_.bindControllerAxis
			(SDL_CONTROLLER_AXIS_TRIGGERRIGHT, &onAxis);

		engine_.input_handler_.bindControllerAxis
			(SDL_CONTROLLER_AXIS_LEFTX, &onRotAxis);

		//tmp
		particle_system_.texture_ = cursor_texture;

	} //loadResources

	void playClickSound(int x, int y) {

		auto click_id = cast(SoundID)ResourceManager.get().getResource!SoundID(GameResource.Click);
		engine_.sound_system_.playSound(click_id, 0.5f, false);

	} //playClickSound

	void playClickSound() {

		auto click_id = cast(SoundID)ResourceManager.get().getResource!SoundID(GameResource.Click);
		engine_.sound_system_.playSound(click_id, 0.5f, false);

	} //playClickSound

	void stopAllSounds(int x, int y ) {

		engine_.sound_system_.stopAllSounds();

	} //stopAllSounds

	void toggleFullscreen(int x, int y) {

		engine_.window_.toggleFullscreen();

	} //toggleFullscreen

	void bindActions() {

		engine_.input_handler_
			.bindMouseBtn(1, &playClickSound, KeyState.UP)
			.bindMouseBtn(3, &stopAllSounds, KeyState.UP);

		engine_.input_handler_.bindKeyEvent(SDL_SCANCODE_ESCAPE, &engine_.window_.quit);

	} //bindActions

	void update() {

		mixin EventManager.doTick;

		bool is_active = (engine_.network_manager_.is_active);

		tick!EventIdentifier(event_manager_);
		entity_manager_.tick!UpdateSystem();

		engine_.network_manager_.draw();
		profiler_.tick();
		visualizer_.tick();

		if (is_active) {
			chat_.tick(); //draw chat window!
		}

		profiler_.sampleUpdate(engine_.update_time_);

		//tmp
		particle_system_.tick(engine_.update_time_, 1.05);

	} //update

	void drawDebug() {

		import blindfire.engine.dbg : render_string;

		auto free_sources = engine_.sound_system_.free_sources;

		auto offset = Vec2i(16, 48);
		engine_.debug_context_.render_string!("free sound sources: %d")(free_sources);

	} //drawDebug

	void draw(double update_dt) {

		entity_manager_.tick!DrawSystem(&engine_.window_, update_dt);

		drawDebug();
		profiler_.sampleFrame(engine_.frame_time_);

		particle_system_.draw(engine_.window_.view_projection);

	} //draw

	void lastDraw(double update_dt) {

		import blindfire.engine.math : Vec2f;

		cursor_.draw(engine_.window_.view_projection, 
			Vec2f(engine_.input_handler_.mouse_x, engine_.input_handler_.mouse_y));

	} //lastDraw

	void run() {

		this.engine_.run();

	} //run

} //Game
