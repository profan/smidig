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

	enum State {
		Playing,
		Free
	} //State

	enum INITIAL_BUFFERS = 16;

	//allocator yes
	IAllocator allocator_;

	//audio device and context
	ALCdevice* device_;
	ALCcontext* context_;

	//containers for references to buffers and sources
	HashMap!(SoundID, ALuint) buffers_;
	Array!State source_states_;
	Array!ALuint sources_;

	//counter for resource ids for loaded sounds
	SoundID current_sound_id;

	@disable this();
	@disable this(this);

	this(size_t num_sources) {
		this.allocator_ = theAllocator;
		this.buffers_ = typeof(buffers_)(allocator_, INITIAL_BUFFERS);
		this.source_states_ = typeof(source_states_)(allocator_, num_sources);
		this.sources_ = typeof(sources_)(allocator_, num_sources);
	} //this

	this(IAllocator allocator, size_t num_sources) {
		this.allocator_ = allocator;
		this.buffers_ = typeof(buffers_)(allocator_, INITIAL_BUFFERS);
		this.source_states_ = typeof(source_states_)(allocator_, num_sources);
		this.sources_ = typeof(sources_)(allocator_, num_sources);
	} //this

	void initialize() {

		this.device_ = alcOpenDevice(null); //preferred device
		this.context_ = alcCreateContext(device_, null);
		alcMakeContextCurrent(context_);

		alGenSources(cast(int)sources_.capacity, sources_.ptr);
		sources_.length = sources_.capacity;
		source_states_.length = source_states_.capacity;

	} //initialize

	~this() {

		alDeleteSources(cast(int)sources_.length, sources_.ptr);
		alDeleteBuffers(cast(int)buffers_.length, buffers_.values.ptr);
		alcMakeContextCurrent(null);
		alcDestroyContext(context_);
		alcCloseDevice(device_);

	} //~this

	auto load_sound_file(char* path) {
		
		import std.string : format, fromStringz;

		auto created_buffer = alureCreateBufferFromFile(path);
		assert(created_buffer != AL_NONE, 
			   format("[SoundSystem] failed creating buffer: %s", fromStringz(alureGetErrorString())));

		buffers_[current_sound_id] = created_buffer;

		return current_sound_id++;

	} //load_sound_file

	void expand_sources() {

		sources_.reserve(sources_.length + 16); //add 16 to sources capacity
		sources_.length = sources_.capacity;
		alGenSources(cast(int)sources_.capacity, sources_.ptr);

	} //expand_sources

	ALuint find_free_source() {

		auto i = 0;

		while (source_states_[i++] == State.Playing) {

		}

		auto source = sources_[i];
		source_states_[i] = State.Playing;

		return source;

	} //find_free_source

	void play_sound(SoundID sound_id, SoundSource sound_source, SoundVolume volume) {

		auto sound_buffer = buffers_[sound_id];

		alSourcei(sound_source, AL_BUFFER, sound_buffer); //associate source with buffer
		alSourcef(sound_source, AL_GAIN, volume);
		alSourcePlay(sound_source);

	} //play_sound

	void play_sound(SoundID sound_id, SoundVolume volume) {

		auto sound_source = find_free_source();
		play_sound(sound_id, sound_source, volume);

	} //play_sound

	void tick() {

		ALint state;
		foreach (i, src_id; sources_) {
			alGetSourcei(src_id, AL_SOURCE_STATE, &state);
			if (state != AL_PLAYING && source_states_[i] == State.Playing) {
				source_states_[i] = State.Free;
			}
		}

	} //tick

	@property uint free_sources() {

		auto free = 0;

		foreach (i, ref state; source_states_) {
			free += (state == State.Free) ? 1 : 0;
		}

		return free;

	} //free_sources

} //SoundSystem