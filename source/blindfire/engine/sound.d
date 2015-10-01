module blindfire.engine.sound;

import core.stdc.stdio : printf;

import derelict.openal.al;
import derelict.alure.alure;

alias SoundID = int;
alias SoundVolume = float;

struct SoundSystem {

	ALCdevice* device;
	ALCcontext* context;

	ALuint[SoundID] buffers;
	ALuint[] sources;

	SoundID current_sound_id;

	@disable this();
	@disable this(this);

	this(size_t num_sources) {
		this.sources.reserve(num_sources);
		this.sources.length = sources.capacity;
	} //this

	void init() {

		this.device = alcOpenDevice(null); //preferred device
		this.context = alcCreateContext(device, null);
		alcMakeContextCurrent(context);

		alGenSources(sources.capacity, sources.ptr);

	} //init

	~this() {

		alDeleteSources(sources.length, sources.ptr);
		alDeleteBuffers(buffers.length, buffers.values.ptr);
		alcMakeContextCurrent(null);
		alcDestroyContext(context);
		alcCloseDevice(device);

	} //~this

	auto load_sound_file(char* path) {
		
		import std.string : format, fromStringz;

		auto created_buffer = alureCreateBufferFromFile(path);
		assert(created_buffer != AL_NONE, 
			   format("[SoundSystem] failed creating buffer: %s", fromStringz(alureGetErrorString())));

		buffers[current_sound_id] = created_buffer;

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

		alSourcei(sound_source, AL_BUFFER, sound_buffer); //associate source with buffer
		alSourcef(sound_source, AL_GAIN, volume);
		alSourcePlay(sound_source);

	} //playSound

	void tick() {

	} //tick

} //SoundSystem