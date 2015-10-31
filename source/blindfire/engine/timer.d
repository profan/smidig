module blindfire.engine.timer;

import derelict.sdl2.sdl;

struct StopWatch {

	import core.time : MonoTimeImpl, ClockType;
	alias Clock = MonoTimeImpl!(ClockType.precise);

	private {

		bool started_;
		long initial_ticks_;
		long passed_ticks_;

	}

	void start() {

		initial_ticks_ = Clock.currTime.ticks;
		started_ = true;

	} //start

	void stop() {

		passed_ticks_ += Clock.currTime.ticks - initial_ticks_;
		started_ = false;

	} //stop

	void reset() {

		if (started_) {
			initial_ticks_ = Clock.currTime.ticks;
		} else {
			initial_ticks_ = 0;
		}

	} //reset

	static long ticksPerSecond() {

		return Clock.ticksPerSecond();

	} //ticksPerSecond

	long peek() {

		if (started_) {
			return Clock.currTime.ticks - initial_ticks_ + passed_ticks_;
		}

		return passed_ticks_;

	} //peek

} //Timer

ulong getPerformanceCounter() {

	return SDL_GetPerformanceCounter();

} //getPerformanceCounter

ulong ticksPerSecond() {

	return SDL_GetPerformanceFrequency();

} //ticksPerSecond

void delayMs(uint ms) {

	SDL_Delay(ms);

} //delayMs
