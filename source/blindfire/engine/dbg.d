module blindfire.engine.dbg;

void render_string(string format, Args...)(ref DebugContext ctx, Args args) {
	import blindfire.engine.util : render_string;
	render_string!(format)(ctx.atlas_, ctx.window_, ctx.offset_, args);
} //render_string

struct DebugContext {

	import blindfire.engine.text : FontAtlas;
	import blindfire.engine.window : Window;
	import blindfire.engine.defs : Vec2i;

	FontAtlas* atlas_;
	Window* window_;
	Vec2i offset_;

	Vec2i initial_offset_;

	this(FontAtlas* atlas, Window* window, Vec2i initial_offset) {
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