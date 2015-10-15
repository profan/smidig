module blindfire.game;

import derelict.sdl2.sdl;

import blindfire.engine.eventhandler : KeyState;
import blindfire.engine.util : render_string;
import blindfire.engine.resource;
import blindfire.engine.event;
import blindfire.engine.defs;

import blindfire.graphics;
import blindfire.defs;
import blindfire.ui;

struct NewGame {

	import blindfire.engine.sound : SoundID;
	import blindfire.engine.runtime;

	enum GameResource : ResourceID {
		Click = Resource.max
	} //GameResource

	private {

		Engine engine_;

	}

	@disable this(this);

	void initialize() {

		//initialize engine systems
		this.engine_.initialize("Project Blindfire", &update, &draw);

		//initialize self
		initialize_systems();
		load_resources();
		bind_actions();

	} //initialize

	void initialize_systems() {

	} //initialize_systems

	void load_resources() {

		auto rm = ResourceManager.get();

		//load click sound
		auto click_file = engine_.sound_system_.load_sound_file(cast(char*)"resource/audio/radiy_click.wav".ptr);
		rm.set_resource!(SoundID)(cast(SoundID*)click_file, GameResource.Click);
	
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

		engine_.input_handler_.bind_mousebtn(1, &play_click_sound, KeyState.UP);
		engine_.input_handler_.bind_mousebtn(3, &stop_all_sounds, KeyState.UP);
		engine_.input_handler_.bind_keyevent(SDL_SCANCODE_SPACE, &toggle_fullscreen);

	} //bind_actions

	void update() {

	} //update

	void draw_debug() {

		import blindfire.engine.dbg : render_string;

		auto free_sources = engine_.sound_system_.free_sources;

		auto offset = Vec2i(16, 48);
		engine_.debug_context_.render_string!("free sound sources: %d")(free_sources);

	} //draw_debug

	void draw() {

		draw_debug();

	} //draw

	void run() {

		this.engine_.run();

	} //run

} //NewGame
