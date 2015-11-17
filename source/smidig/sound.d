module smidig.sound;

import core.stdc.stdio : printf;

import derelict.openal.al;
import derelict.alure.alure;

import smidig.memory : IAllocator;
import smidig.collections : Array, ArraySOA, HashMap;

alias SoundID = int;
alias SoundVolume = float;
alias SoundBuffer = ALuint;
alias SoundSource = ALuint;

auto to(T:ALboolean)(bool b) {
	return (b) ? AL_TRUE : AL_FALSE;
} //to

struct SoundSystem {

	enum State {
		Playing,
		Looping,
		Paused,
		Free
	} //State

	static struct Source {
		SoundSource source;
		State state;
	} //Source

	enum INITIAL_BUFFERS = 16;

	//allocator yes
	IAllocator allocator_;

	//audio device and context
	ALCdevice* device_;
	ALCcontext* context_;

	//containers for references to buffers and sources
	HashMap!(SoundID, SoundBuffer) buffers_;
	ArraySOA!Source sources_;

	//counter for resource ids for loaded sounds
	SoundID current_sound_id_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t num_sources) {
		this.allocator_ = allocator;
		this.buffers_ = typeof(buffers_)(allocator_, INITIAL_BUFFERS);
		this.sources_ = typeof(sources_)(allocator_, num_sources);
	} //this

	void initialize() {

		//TODO handle and check errors upon initialization

		this.device_ = alcOpenDevice(null); //preferred device
		this.context_ = alcCreateContext(device_, null);
		alcMakeContextCurrent(context_);

		alGenSources(cast(int)sources_.capacity, sources_.source.ptr);
		sources_.length = sources_.capacity;

	} //initialize

	~this() {

		alDeleteSources(cast(int)sources_.length, sources_.source.ptr);
		alDeleteBuffers(cast(int)buffers_.length, buffers_.values.ptr);
		alcMakeContextCurrent(null);
		alcDestroyContext(context_);
		alcCloseDevice(device_);

	} //~this

	void expandSources() {

		sources_.reserve(sources_.length + 16); //add 16 to sources capacity
		sources_.length = sources_.capacity;
		alGenSources(cast(int)sources_.capacity, sources_.source.ptr);

	} //expandSources

	auto loadSoundFile(char* path) {
		
		import std.string : format, fromStringz;

		auto created_buffer = alureCreateBufferFromFile(path);
		assert(created_buffer != AL_NONE, 
			   format("[SoundSystem] failed creating buffer: %s", fromStringz(alureGetErrorString())));

		buffers_[current_sound_id_] = created_buffer;

		return current_sound_id_++;

	} //loadSoundFile

	ALint findFreeSourceIndex() {

		enum error = -1;

		foreach (src_index, state; sources_.state) {
			if (state == State.Free) {
				return cast(ALint)src_index;
			}
		}

		return error;

	} //findFreeSourceIndex

	void playSound(SoundID sound_id, ALint source_id, SoundVolume volume, bool loop) {

		auto sound_buffer = buffers_[sound_id];
		auto sound_source = sources_.source[source_id];
		sources_.state[source_id] = (loop) ? State.Looping : State.Playing;

		alSourcei(sound_source, AL_LOOPING, to!ALboolean(loop));
		alSourcei(sound_source, AL_BUFFER, sound_buffer); //associate source with buffer
		alSourcef(sound_source, AL_GAIN, volume);
		alSourcePlay(sound_source);

	} //playSound

	void playSound(SoundID sound_id, SoundVolume volume, bool loop = false) {

		auto sound_source = findFreeSourceIndex();

		if (sound_source != -1) { //otherwise, we couldn't find a source
			playSound(sound_id, sound_source, volume, loop);
		}

	} //playSound

	void pauseAllSounds() {

		foreach (src_id, source; sources_.source) {
			alSourcePause(source);
		}

	} //pauseAllSounds

	void stopAllSounds() {

		foreach (src_id, source; sources_.source) {
			sources_.state[src_id] = State.Free;
			alSourceStop(source);
		}

	} //stopAllSounds

	void tick() {

		ALint state;
		foreach (i, src_id; sources_.source) {
			alGetSourcei(src_id, AL_SOURCE_STATE, &state);
			if (state != AL_PLAYING && sources_.state[i] == State.Playing) {
				sources_.state[i] = State.Free;
			}
		}

	} //tick

	@property uint numFreeSources() {

		auto free = 0;

		foreach (i, ref state; sources_.state) {
			free += (state == State.Free) ? 1 : 0;
		}

		return free;

	} //numFreeSources

} //SoundSystem
