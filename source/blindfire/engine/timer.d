module blindfire.engine.timer;

import derelict.sdl2.sdl;

struct StopWatch {

	import core.time : MonoTimeImpl, ClockType;
	alias Clock = MonoTimeImpl!(ClockType.precise);

	long initial_ticks;
	long passed_ticks;

	void start() {

		initial_ticks = Clock.currTime.ticks;

	} //start

	void reset() {

		initial_ticks = Clock.currTime.ticks;

	} //reset

	static long ticks_per_second() {

		return Clock.ticksPerSecond();

	} //ticks_per_second

	long peek() {

		return Clock.currTime.ticks - initial_ticks + passed_ticks;

	} //peek

} //Timer

ulong get_performance_counter() {

	return SDL_GetPerformanceCounter();

} //get_performance_counter

ulong ticks_per_second() {

	return SDL_GetPerformanceFrequency();

} //ticks_per_second