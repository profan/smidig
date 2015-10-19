module blindfire.engine.profiler;


struct Profiler {

	import blindfire.engine.memory : IAllocator;

	private {

		IAllocator allocator_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;

	} //this

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Profiler");



	} //tick

} //Profiler