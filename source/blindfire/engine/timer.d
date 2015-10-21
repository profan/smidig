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

	static long ticks_per_second() {

		return Clock.ticksPerSecond();

	} //ticks_per_second

	long peek() {

		if (started_) {
			return Clock.currTime.ticks - initial_ticks_ + passed_ticks_;
		}

		return passed_ticks_;

	} //peek

} //Timer

struct WaitableTimer {

	version(none) {

		import core.stdc.stdio : printf;
		import windows.windows;

		HANDLE timer_ = null;

		@disable this();
		@disable this(this);

		this(bool manual_reset) {
			this.timer_ = CreateWaitableTimer(null, manual_reset, null);
			if (!timer_) {
				printf("CreateWaitableTimer failed (%d)\n", GetLastError());
			}
		} //this

		int set_wait(LARGE_INTEGER time) {

			return SetWaitableTimer(timer_, &time, 0, null, null, 0);

		} //set_wait_time

		void wait_for() {

			WaitForSingleObject(timer_, INFINITE);

		} //wait_for

	}

} //WaitableTimer

ulong get_performance_counter() {

	return SDL_GetPerformanceCounter();

} //get_performance_counter

ulong ticks_per_second() {

	return SDL_GetPerformanceFrequency();

} //ticks_per_second