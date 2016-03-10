module smidig.dbg;

ref DebugContext render_string(string format, Args...)(ref DebugContext ctx, Args args) {

	import smidig.util : render_string;
	render_string!(format)(ctx.atlas_, *ctx.window_, ctx.offset_, args);

	return ctx;

} //render_string

struct DebugContext {

	import smidig.collections : Array, HashMap;
	import smidig.memory : IAllocator;
	import smidig.imgui : Imgui;
	import smidig.window : Window;
	import smidig.gl : FontAtlas;
	import smidig.defs : Vec2i;

	/* allocator */
	IAllocator allocator_;

	/* generic state */
	FontAtlas* atlas_;
	Window* window_;
	Vec2i offset_;

	Vec2i initial_offset_;

	/* imgui related state */
	Imgui* context_;

	this(IAllocator allocator, Imgui* context, FontAtlas* atlas, Window* window, Vec2i initial_offset) {
		this.allocator_ = allocator;
		this.context_ = context;
		this.atlas_ = atlas;
		this.window_ = window;
		this.offset_ = initial_offset;
		this.initial_offset_ = initial_offset;
	} //this

	void reset() {
		offset_ = initial_offset_;
	} //reset

} //DebugContext
