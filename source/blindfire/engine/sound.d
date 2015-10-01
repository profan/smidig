module blindfire.engine.sound;

import derelict.openal.al;

alias SoundID = int;
alias SoundVolume = int;

struct SoundSystem {

	enum NUM_BUFFERS = 3;
	enum NUM_SOURCES = 32;

	@disable this();
	@disable this(this);

	ALCdevice* device;
	ALCcontext* context;

	ALuint[NUM_BUFFERS] buffer;
	ALuint[NUM_SOURCES] source;

	void init() {

		this.device = alcOpenDevice(null); //preferred device
		this.context = alcCreateContext(device, null);

		alGetError();
		alGenBuffers(NUM_BUFFERS, buffer.ptr);

	} //init

	~this() {

	} //~this

	void playSound(SoundID sound, SoundVolume volume) {

	} //playSound

} //SoundSystem