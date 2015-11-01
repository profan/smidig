module blindfire.engine.utils.profiler;

struct Profiler {

	import blindfire.engine.collections : CircularBuffer;
	import blindfire.engine.memory : IAllocator;

	enum FRAME_SAMPLES = 256;

	private {

		IAllocator allocator_;

		CircularBuffer!float updatetimes_;
		CircularBuffer!float frametimes_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.updatetimes_ = typeof(updatetimes_)(allocator_, FRAME_SAMPLES);
		this.frametimes_ = typeof(frametimes_)(allocator_, FRAME_SAMPLES);

	} //this

	void sampleUpdate(double updatetime) {

		//add sample to buffer
		updatetimes_ ~= cast(float)updatetime;

	} //sampleUpdate

	void sampleFrame(double frametime) {

		//add sample to buffer
		frametimes_ ~= cast(float)frametime;

	} //sampleFrame

	alias Callback = float delegate(int idx);

	static extern(C) float doCallback(void* ptr, int idx) {

		auto callback = *(cast(Callback*) ptr);
		return callback(idx);

	} //doCallback;

	void push(in char[] name, long ticks) {

	} //push

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Profiler");

		auto update_callback = &updatetimes_.last;
		auto frame_callback = &frametimes_.last;

		igPlotLines2("update times", &doCallback, cast(void*)&update_callback, cast(int)updatetimes_.length, 0, null, float.max, float.max, ImVec2(256, 64));
		igPlotLines2("frame times", &doCallback, cast(void*)&frame_callback, cast(int)frametimes_.length, 0, null, float.max, float.max, ImVec2(256, 64));

		igEnd();

	} //tick

} //Profiler

struct ProfilerRegion {

	import blindfire.engine.timer : StopWatch;

	const(char[]) name_;
	StopWatch sw_;
	Profiler* output_;

	this(in char[] name, ref Profiler output) {
		this.name_ = name;
		this.output_ = &output;
		sw_.start();
	} //this

	~this() {
		sw_.stop();
		output_.push(name_, sw_.peek());
	} //~this

} //ProfilerRegion
