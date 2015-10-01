module blindfire.engine.sound;

import std.stdio : writefln;

import derelict.openal.al;
import derelict.alure.alure;

alias SoundID = int;
alias SoundVolume = int;

struct SoundSystem {

	enum NUM_BUFFERS = 3;
	enum NUM_SOURCES = 32;

	@disable this(this);

	ALCdevice* device;
	ALCcontext* context;

	ALuint[NUM_BUFFERS] buffer;
	ALuint[NUM_SOURCES] source;

	void init() {

		import core.stdc.stdio : printf;

		this.device = alcOpenDevice(null); //preferred device
		this.context = alcCreateContext(device, null);
		alcMakeContextCurrent(context);

		buffer[0] = alureCreateBufferFromFile(cast(char*)"resource/audio/paniq.wav".ptr);
		printf("Error: %d : %s\n", alGetError(), alureGetErrorString());

		alGenSources(NUM_SOURCES, source.ptr);
		alSourcei(source[0], AL_BUFFER, buffer[0]);
		printf("Error: %d : %s\n", alGetError(), alureGetErrorString());

		alSourcef(source[0], AL_GAIN, 0.25f);
		alSourcePlay(source[0]);

	} //init

	~this() {

		alDeleteSources(NUM_SOURCES, source.ptr);
		alDeleteBuffers(NUM_BUFFERS, buffer.ptr);

	} //~this

	void playSound(SoundID sound, SoundVolume volume) {

	} //playSound

} //SoundSystem