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

struct NewGame {

	import blindfire.engine.memory : make;
	import blindfire.engine.profiler : Profiler;
	import blindfire.engine.sound : SoundID;
	import blindfire.engine.pool : construct;
	import blindfire.engine.runtime;
	import blindfire.engine.joy;
	import blindfire.engine.ecs;

	import blindfire.chat;
	import blindfire.sys;

	enum GameResource : ResourceID {
		Click = Resource.max+1,
		BasicShader,
		CursorTexture
	} //GameResource

	private {

		Engine engine_;
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

	}

	@disable this(this);

	void initialize() {

		//initialize engine systems
		this.engine_.initialize("Project Blindfire", &update, &draw, &last_draw);

		//initialize self
		initialize_systems();
		load_resources();
		bind_actions();

	} //initialize

	void initialize_systems() {

		auto ea = engine_.allocator_;

		this.chat_.construct(ea, &engine_.network_evman_);
		engine_.network_evman_.register!ConnectionEvent(&chat_.on_peer_connect);
		engine_.network_evman_.register!DisconnectionEvent(&chat_.on_peer_disconnect);
		engine_.network_evman_.register!UpdateEvent(&chat_.on_network_update);

		this.profiler_.construct(ea);
		this.visualizer_.construct(&engine_.input_handler_);

		//game test
		this.event_manager_.construct(EventMemory, EventType.max);
		this.entity_manager_ = ea.make!EntityManager(engine_.allocator_);

		//systems
		auto t_man = ea.make!TransformManager();
		auto c_man = ea.make!CollisionManager(Vec2i(640, 480));
		auto s_man = ea.make!SpriteManager();

		event_manager_.register!AnalogAxisEvent(&t_man.onAnalogMovement);
		event_manager_.register!AnalogRotEvent(&t_man.onAnalogRotation);
		entity_manager_.addSystems(t_man, c_man, s_man);

	} //initialize_systems

	void load_resources() {

		import blindfire.engine.gl : AttribLocation, Shader, Texture;
		import blindfire.engine.memory : make;

		auto rm = ResourceManager.get();
		auto ea = engine_.allocator_;

		//load click sound
		auto click_file = engine_.sound_system_.load_sound_file(cast(char*)"resource/audio/radiy_click.wav".ptr);
		rm.set_resource!(SoundID)(cast(SoundID*)click_file, GameResource.Click);

		//basic shader
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = ea.make!Shader("shaders/basic", attributes[], uniforms[]);
		rm.set_resource(shader, GameResource.BasicShader);

		//mouse pointer texture
		auto cursor_texture = ea.make!Texture("resource/img/other_cursor.png");
		rm.set_resource(cursor_texture, GameResource.CursorTexture);
		this.cursor_.construct(cursor_texture, shader);

		//create unit
		import blindfire.ents : create_unit;
		auto unit = create_unit(entity_manager_, Vec2f(320, 240), shader, cursor_texture);

		void on_axis(int value) {
			event_manager_.push!AnalogAxisEvent(AxisPayload(unit, value));
		} //on_axis

		void on_rot_axis(int value) {
			event_manager_.push!AnalogRotEvent(AxisPayload(unit, value));
		} //on_rot_axis

		engine_.input_handler_.bind_controlleraxis
			(SDL_CONTROLLER_AXIS_TRIGGERRIGHT, &on_axis);

		engine_.input_handler_.bind_controlleraxis
			(SDL_CONTROLLER_AXIS_LEFTX, &on_rot_axis);

	} //load_resources

	void play_click_sound(int x, int y) {

		auto click_id = cast(SoundID)ResourceManager.get().get_resource!SoundID(GameResource.Click);
		engine_.sound_system_.play_sound(click_id, 0.5f, false);

	} //play_click_sound

	void play_click_sound() {

		auto click_id = cast(SoundID)ResourceManager.get().get_resource!SoundID(GameResource.Click);
		engine_.sound_system_.play_sound(click_id, 0.5f, false);

	} //play_click_sound

	void stop_all_sounds(int x, int y ) {

		engine_.sound_system_.stop_all_sounds();

	} //stop_all_sounds

	void toggle_fullscreen() {

		engine_.window_.toggle_fullscreen();

	} //toggle_fullscreen

	void bind_actions() {

		engine_.input_handler_
			.bind_mousebtn(1, &play_click_sound, KeyState.UP)
			.bind_mousebtn(3, &stop_all_sounds, KeyState.UP);

	} //bind_actions

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

		profiler_.sample_update(engine_.update_time_);

	} //update

	void draw_debug() {

		import blindfire.engine.dbg : render_string;

		auto free_sources = engine_.sound_system_.free_sources;

		auto offset = Vec2i(16, 48);
		engine_.debug_context_.render_string!("free sound sources: %d")(free_sources);

	} //draw_debug

	void draw() {

		entity_manager_.tick!DrawSystem(&engine_.window_);

		draw_debug();
		profiler_.sample_frame(engine_.frame_time_);

	} //draw

	void last_draw() {

		import blindfire.engine.math : Vec2f;

		cursor_.draw(engine_.window_.view_projection, 
			Vec2f(engine_.input_handler_.mouse_x, engine_.input_handler_.mouse_y));

	} //last_draw

	void run() {

		this.engine_.run();

	} //run

} //NewGame
