module blindfire.engine.sound;

import derelict.openal.al;
import derelict.alure.alure;

alias SoundID = int;
alias SoundVolume = float;

struct SoundSystem {

	import core.stdc.stdio : printf;

	@disable this();
	@disable this(this);

	ALCdevice* device;
	ALCcontext* context;

	ALuint[SoundID] buffers;
	ALuint[] sources;

	SoundID current_sound_id;

	this(size_t num_sources) {
		this.sources.reserve(num_sources);
		this.sources.length = sources.capacity;
	}

	void init() {


		this.device = alcOpenDevice(null); //preferred device
		this.context = alcCreateContext(device, null);
		alcMakeContextCurrent(context);

		alGenSources(sources.capacity, sources.ptr);

	} //init

	~this() {

		alDeleteSources(sources.length, sources.ptr);
		alDeleteBuffers(buffers.length, buffers.values.ptr);

	} //~this

	auto load_sound_file(char* path) {

		buffers[current_sound_id] = alureCreateBufferFromFile(path);
		printf("Error: %d : %s\n", alGetError(), alureGetErrorString());

		return current_sound_id++;

	} //load_sound_file

	ALuint find_free_source() {

		auto source = sources[0];
		sources = sources[1..$];

		return source;

	} //find_free_source

	void play_sound(SoundID sound_id, SoundVolume volume) {

		auto sound_buffer = buffers[sound_id];
		auto sound_source = find_free_source();
		alSourcei(sound_source, AL_BUFFER, sound_buffer);
		alSourcef(sound_source, AL_GAIN, volume);
		alSourcePlay(sound_source);

	} //playSound

	void tick() {

	} //tick

} //SoundSystem