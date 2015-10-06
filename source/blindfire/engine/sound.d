module blindfire.engine.sound;

import core.stdc.stdio : printf;

import derelict.openal.al;
import derelict.alure.alure;

import blindfire.engine.memory : IAllocator, theAllocator;
import blindfire.engine.collections : Array, HashMap;

alias SoundID = int;
alias SoundVolume = float;
alias SoundSource = ALuint;

struct SoundSystem {

	enum INITIAL_BUFFERS = 16;

	IAllocator allocator_;

	ALCdevice* device;
	ALCcontext* context;

	HashMap!(SoundID, ALuint) buffers;
	Array!ALuint sources;

	SoundID current_sound_id;

	@disable this();
	@disable this(this);

	this(size_t num_sources) {
		this.allocator_ = theAllocator;
		this.buffers = typeof(buffers)(allocator_, INITIAL_BUFFERS);
		this.sources = typeof(sources)(allocator_, num_sources);
		this.sources.length = sources.capacity;
	} //this

	this(IAllocator allocator, size_t num_sources) {
		this.buffers = typeof(buffers)(allocator, INITIAL_BUFFERS);
		this.sources = typeof(sources)(allocator, num_sources);
		this.sources.length = sources.capacity;
	} //this

	void initialize() {

		this.device = alcOpenDevice(null); //preferred device
		this.context = alcCreateContext(device, null);
		alcMakeContextCurrent(context);

		alGenSources(sources.capacity, sources.ptr);

	} //initialize

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

	void expand_sources() {

		sources.reserve(16); //add 16 to sources capacity
		sources.length = sources.capacity;
		alGenSources(sources.capacity, sources.ptr);

	} //expand_sources

	ALuint find_free_source() {

		auto source = sources[0];
		sources.remove(0);

		return source;

	} //find_free_source

	void play_sound(SoundID sound_id, SoundSource sound_source, SoundVolume volume) {

		auto sound_buffer = buffers[sound_id];

		alSourcei(sound_source, AL_BUFFER, sound_buffer); //associate source with buffer
		alSourcef(sound_source, AL_GAIN, volume);
		alSourcePlay(sound_source);

	} //play_sound

	void play_sound(SoundID sound_id, SoundVolume volume) {

		auto sound_source = find_free_source();
		play_sound(sound_id, sound_source, volume);

	} //play_sound

	void tick() {

	} //tick

} //SoundSystem