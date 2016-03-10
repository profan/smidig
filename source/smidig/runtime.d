module smidig.runtime;

import smidig.memory : IAllocator;
import smidig.modules;

struct Engine {

	enum Error {
		WindowInitFailed,
		SoundInitFailed,
		NetInitFailed,
		Success
	} //Error

	alias UpdateFunc = void delegate();
	alias DrawFunc = void delegate(double);
	alias RunFunc = void delegate();

	/* is running flag */
	bool is_alive_ = true;

	/* engine allocator */
	IAllocator allocator_;

	/* allocate subsystems somewhere here? */

	/* run loop counters */
	double update_time_;
	double frame_time_;
	double draw_time_;

	//TODO: find out what time unit?
	double time_since_last_update_;

	/* controls tick/draw speed */
	/* both are in ticks/sec */
	int update_rate_ = 30;
	int draw_rate_ = 60;

	/* runs on every update tick. */
	UpdateFunc update_function_;

	/* runs before anything else draws in the engine. */
	DrawFunc draw_function_;

	/* runs after engine has drawn everything else. */
	DrawFunc post_draw_function_;

	/* no copying. */
	@disable this(this);

	@property {

		int update_rate(int new_update_rate) {

			if (new_update_rate > 0) {
				return update_rate_ = new_update_rate;
			}

			return update_rate_;

		} //update_rate

		int update_rate() const {
			return update_rate_;
		} //update_rate

		int draw_rate(int new_draw_rate) {

			if (new_draw_rate > 0) {
				return draw_rate_ = new_draw_rate;
			}

			return draw_rate_;

		} //draw_rate

		int draw_rate() const {
			return draw_rate_;
		} //draw_rate

		void quit() {
			is_alive_ = false;
		} //quit

	}

	static Error create(ref Engine engine, in char[] title, UpdateFunc update_func, DrawFunc draw_func, DrawFunc post_draw_func) {

		with (engine) {

			/* for every dependency, initialize. */

			/* for every dependency, perform linking to eachother. */

			/* refs into userspace */
			update_function_ = update_func;
			draw_function_ = draw_func;
			post_draw_function_ = post_draw_func;

		}

		return Error.Success;

	} //create

	void draw(double dt, double update_dt) {

	} //draw

	void debug_draw(double dt) {

	} //debug_draw

	void run() {

		import smidig.timer : StopWatch;

		/* keeps track of total runtime. */
		StopWatch main_timer; 

		/* tracks update, draw and total frame runtimes respectively. */
		StopWatch update_timer, draw_timer, frame_timer;

		/* stores ticks/iteration for update and draw. */
		long update_iter, draw_iter;

		/* stores tick when last update and draw happened. */
		long last_update, last_render;

		/* stopwatch clock ticks per second. */
		long ticks_per_second = StopWatch.ticksPerSecond();

		/* start all. */
		main_timer.start();
		update_timer.start();
		draw_timer.start();
		frame_timer.start();

		while (is_alive_) {

			/* recalculate every iteration because it may change. */
			/* TODO: put in setters instead? */
			update_iter = ticks_per_second / update_rate_;
			draw_iter = ticks_per_second / draw_rate_;

			/* check if it's time to do an update tick. */
			if (main_timer.peek() - last_update > update_iter) {

				update_timer.start();

				/* delegate by user. */
				this.update_function_();

				/* calc update time in seconds. */
				update_time_ = cast(double)update_timer.peek() / cast(double)ticks_per_second;
				last_update = main_timer.peek();
				update_timer.reset();

			}

			draw_timer.start();

			draw_timer.reset();

			frame_timer.reset();

		}

	} //run

} //Engine
