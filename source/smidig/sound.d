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

	enum Error {
		FailedOpeningDevice,
		FailedCreatingContext,
		FailedMakingContextCurrent,
		Success
	} //Error

	//TODO: take a look at this later, should it be a constant?
	enum INITIAL_BUFFERS = 16;

	enum State {
		Playing,
		Looping,
		Paused,
		Free
	} //State

	static struct Source {
		SoundSource sources;
		State states;
	} //Source

	private {

		//audio device and context
		ALCdevice* device_;
		ALCcontext* context_;

		//containers for references to buffers and sources
		HashMap!(SoundID, SoundBuffer) buffers_;
		ArraySOA!Source sources_;

		//counter for resource ids for loaded sounds
		SoundID current_sound_id_;

	}

	@disable this(this);

	private this(IAllocator allocator, size_t num_sources) {
		this.buffers_ = typeof(buffers_)(allocator, INITIAL_BUFFERS);
		this.sources_ = typeof(sources_)(allocator, num_sources);
	} //this

	static Error create(ref SoundSystem system, IAllocator allocator, size_t num_sources) {

		assert(allocator);

		system = SoundSystem(allocator, num_sources);

		system.device_ = alcOpenDevice(null); //preferred device
		if (!system.device_) { return Error.FailedOpeningDevice; }

		system.context_ = alcCreateContext(system.device_, null);
		if (!system.context_) { return Error.FailedCreatingContext; }

		auto result = alcMakeContextCurrent(system.context_); //is ok, try making current
		if (result == ALC_FALSE) { return Error.FailedMakingContextCurrent; }

		with (system) {
			alGenSources(cast(int)sources_.capacity, sources_.sources.ptr);
			sources_.length = sources_.capacity;
		}

		return Error.Success;

	} //create

	~this() {

		if (device_ && context_ ) { //FUCKING WOW? ughhhhh
			alDeleteSources(cast(int)sources_.length, sources_.sources.ptr);
			alDeleteBuffers(cast(int)buffers_.length, buffers_.values.ptr);
			alcMakeContextCurrent(null);
			alcDestroyContext(context_);
			alcCloseDevice(device_);
		}

	} //~this

	void expandSources() {

		sources_.reserve(sources_.length + 16); //add 16 to sources capacity
		sources_.length = sources_.capacity;
		alGenSources(cast(int)sources_.capacity, sources_.sources.ptr);

	} //expandSources

	/**
	 * Reads a file from disk given a path, adding it to the list of sound buffers, returning the ID assigned.
	*/
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

		foreach (src_index, state; sources_.states) {
			if (state == State.Free) {
				return cast(ALint)src_index;
			}
		}

		return error;

	} //findFreeSourceIndex

	void playSound(SoundID sound_id, ALint source_id, SoundVolume volume, bool loop) {

		auto sound_buffer = buffers_[sound_id];
		auto sound_source = sources_.sources[source_id];
		sources_.states[source_id] = (loop) ? State.Looping : State.Playing;

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

		foreach (src_id, source; sources_.sources) {
			alSourcePause(source);
		}

	} //pauseAllSounds

	void stopAllSounds() {

		foreach (src_id, source; sources_.sources) {
			sources_.states[src_id] = State.Free;
			alSourceStop(source);
		}

	} //stopAllSounds

	void tick() {

		ALint state;
		foreach (i, src_id; sources_.sources) {
			alGetSourcei(src_id, AL_SOURCE_STATE, &state);
			if (state != AL_PLAYING && sources_.states[i] == State.Playing) {
				sources_.states[i] = State.Free;
			}
		}

	} //tick

	@property uint numFreeSources() {

		auto free = 0;

		foreach (i, ref state; sources_.states) {
			free += (state == State.Free) ? 1 : 0;
		}

		return free;

	} //numFreeSources

} //SoundSystem
