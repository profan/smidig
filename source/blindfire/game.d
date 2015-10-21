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

	import blindfire.engine.profiler : Profiler;
	import blindfire.engine.sound : SoundID;
	import blindfire.engine.pool : construct;
	import blindfire.engine.runtime;

	import blindfire.chat;

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

		this.chat_.construct(engine_.allocator_, &engine_.network_evman_);
		engine_.network_evman_.register!ConnectionEvent(&chat_.on_peer_connect);
		engine_.network_evman_.register!DisconnectionEvent(&chat_.on_peer_disconnect);
		engine_.network_evman_.register!UpdateEvent(&chat_.on_network_update);

		this.profiler_.construct(engine_.allocator_);

	} //initialize_systems

	void load_resources() {

		import blindfire.engine.gl : AttribLocation, Shader, Texture;
		import blindfire.engine.memory : make;

		auto rm = ResourceManager.get();

		//load click sound
		auto click_file = engine_.sound_system_.load_sound_file(cast(char*)"resource/audio/radiy_click.wav".ptr);
		rm.set_resource!(SoundID)(cast(SoundID*)click_file, GameResource.Click);

		//basic shader
		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		auto shader = engine_.allocator_.make!Shader("shaders/basic", attributes[], uniforms[]);
		rm.set_resource(shader, GameResource.BasicShader);

		//mouse pointer texture
		auto cursor_texture = engine_.allocator_.make!Texture("resource/img/other_cursor.png");
		rm.set_resource(cursor_texture, GameResource.CursorTexture);
		this.cursor_.construct(cursor_texture, shader);

	} //load_resources

	void play_click_sound(int x, int y) {

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

		bool is_active = (engine_.network_manager_.is_active);

		engine_.network_manager_.draw();
		profiler_.tick();

		if (is_active) {
			chat_.tick(); //draw chat window!
		}

	} //update

	void draw_debug() {

		import blindfire.engine.dbg : render_string;

		auto free_sources = engine_.sound_system_.free_sources;

		auto offset = Vec2i(16, 48);
		engine_.debug_context_.render_string!("free sound sources: %d")(free_sources);

	} //draw_debug

	void draw() {

		draw_debug();
		profiler_.sample(engine_.frame_time_);

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
