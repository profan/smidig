module blindfire.engine.profiler;


struct Profiler {

	import blindfire.engine.collections : CircularBuffer;
	import blindfire.engine.memory : IAllocator;

	enum FRAME_SAMPLES = 512;

	private {

		IAllocator allocator_;

		CircularBuffer!float frametimes_;

		uint samples_past;
		float cur_max;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.frametimes_ = typeof(frametimes_)(allocator_, FRAME_SAMPLES);

	} //this

	void sample(double frametime) {

		//add sample to buffer
		frametimes_ ~= cast(float)frametime;

	} //sample

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Profiler");

		igPlotLines("frametimes", frametimes_.ptr, frametimes_.length, 0, null, float.max, float.max, ImVec2(256, 64));

		igEnd();

	} //tick

} //Profiler