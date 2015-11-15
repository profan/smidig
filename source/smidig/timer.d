module smidig.timer;

import derelict.sdl2.sdl;

struct StopWatch {

	version(DigitalMars) {

		import core.time : MonoTimeImpl, ClockType;
		alias Clock = MonoTimeImpl!(ClockType.precise);
		alias TicksPerSecond = Clock.ticksPerSecond;

	} else version(GNU) {

		import core.time : TickDuration;
		alias TicksPerSecond = TickDuration.ticksPerSec;

	}

	private {

		bool started_;
		long initial_ticks_;
		long passed_ticks_;

	}

	@property auto currTicks() {

		version(DigitalMars) {
			return Clock.currTime.ticks;
		} else version(GNU) {
			return TickDuration.currSystemTick.length;
		}

	} //currTicks

	void start() {

		initial_ticks_ = currTicks;
		started_ = true;

	} //start

	void stop() {

		passed_ticks_ += currTicks - initial_ticks_;
		started_ = false;

	} //stop

	void reset() {

		if (started_) {
			initial_ticks_ = currTicks;
		} else {
			initial_ticks_ = 0;
		}

	} //reset

	static long ticksPerSecond() {

		return TicksPerSecond;

	} //ticksPerSecond

	long peek() {

		if (started_) {
			return currTicks - initial_ticks_ + passed_ticks_;
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
