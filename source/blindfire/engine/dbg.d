module blindfire.engine.dbg;

void render_string(string format, Args...)(ref DebugContext ctx, Args args) {
	import blindfire.engine.util : render_string;
	render_string!(format)(ctx.atlas_, ctx.window_, ctx.offset_, args);
} //render_string

struct DebugContext {

	import blindfire.engine.collections : Array, HashMap;
	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.imgui : ImguiContext;
	import blindfire.engine.window : Window;
	import blindfire.engine.gl : FontAtlas;
	import blindfire.engine.defs : Vec2i;

	struct Option {

		enum Type {
			Int
		}

	} //Option

	/* allocator */
	IAllocator allocator_;

	/* generic state */
	FontAtlas* atlas_;
	Window* window_;
	Vec2i offset_;

	Vec2i initial_offset_;

	/* imgui related state */
	ImguiContext* context_;
	Option* option_root_;

	this(IAllocator allocator, ImguiContext* context, FontAtlas* atlas, Window* window, Vec2i initial_offset) {
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

class Debug {



} //Debug