module blindfire.engine.profiler;


struct Profiler {

	import blindfire.engine.collections : CircularBuffer;
	import blindfire.engine.memory : IAllocator;

	enum FRAME_SAMPLES = 200;

	private {

		IAllocator allocator_;

		CircularBuffer!double frametimes_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.frametimes_ = typeof(frametimes_)(allocator_, FRAME_SAMPLES);

	} //this

	void tick(double frametime) {

		//add sample to buffer
		frametimes_ ~= frametime;

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Profiler");

		igEnd();

	} //tick

} //Profiler