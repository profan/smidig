module blindfire.engine.profiler;


struct Profiler {

	import blindfire.engine.collections : CircularBuffer;
	import blindfire.engine.memory : IAllocator;

	enum FRAME_SAMPLES = 512;

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

	void sample_update(double updatetime) {

		//add sample to buffer
		updatetimes_ ~= cast(float)updatetime;

	} //sample_update

	void sample_frame(double frametime) {

		//add sample to buffer
		frametimes_ ~= cast(float)frametime;

	} //sample

	struct Data {
		float delegate(int idx) callback;
	} //Data

	static extern(C) float do_callback(void* ptr, int idx) {

		auto d = *(cast(Data*) ptr);
		return d.callback(idx);

	} //do_callback;

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Profiler");

		auto update_callback = Data(&updatetimes_.last);
		auto frame_callback = Data(&frametimes_.last);

		igPlotLines2("update times", &do_callback, cast(void*)&update_callback, updatetimes_.length, 0, null, float.max, float.max, ImVec2(256, 64));
		igPlotLines2("frame times", &do_callback, cast(void*)&frame_callback, frametimes_.length, 0, null, float.max, float.max, ImVec2(256, 64));

		igEnd();

	} //tick

} //Profiler