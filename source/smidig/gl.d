module smidig.gl;

import core.stdc.stdio : printf;
import std.stdio : writefln;

import derelict.opengl3.gl3;
import tested : name;

import smidig.math : Vec2i, Vec2f, Vec3f, Mat3f, Mat4f;
import smidig.collections : StringBuffer;

alias GLColor = GLfloat[4];

/**
 * Used to convert types to the representation needed for OpenGL to interpret the data properly,
 * for example when uploading data with a $(D VertexArray).
*/
template TypeToGLenum(T) {

	import std.format : format;

	static if (is (T == float)) {
		enum TypeToGLenum = GL_FLOAT;
	} else static if (is (T == double)) {
		enum TypeToGLenum = GL_DOUBLE;
	} else static if (is (T == int)) {
		enum TypeToGLenum = GL_INT;
	} else static if (is (T == uint)) {
		enum TypeToGLenum = GL_UNSIGNED_INT;
	} else static if (is (T == short)) {
		enum TypeToGLenum = GL_SHORT;
	} else static if (is (T == ushort)) {
		enum TypeToGLenum = GL_UNSIGNED_SHORT;
	} else static if (is (T == byte)) {
		enum TypeToGLenum = GL_BYTE;
	} else static if (is (T == ubyte) || is(T == void)) {
		enum TypeToGLenum = GL_UNSIGNED_BYTE;
	} else {
		static assert (0, format("No type conversion found for: %s to GL equivalent", T.stringof));
	}

} //TypeToGLenum

/**
 * Converts passed type to given GL uniform function equivalent, returning an alias to it.
*/
template TypeToUniformFunction(T) {

} //TypeToUniformFunction

/**
 * Represents Vertex Buffer hints to the GPU, Static meaning it should never change,
 * Dynamic for when it changes now and then, Stream for when it may change every single frame.
 * The GPU *may* place it accordingly in memory given these hints.
*/
enum DrawType {

	Static,
	Dynamic,
	Stream

} //DrawType

enum Primitive {

	Points = GL_POINTS,
	Lines = GL_LINES,
	LineStrip = GL_LINE_STRIP,
	LineLoop = GL_LINE_LOOP,
	Triangles = GL_TRIANGLES,
	TriangleStrip = GL_TRIANGLE_STRIP,
	TriangleFan = GL_TRIANGLE_FAN,

} //Primitive

/**
 * Generic VertexArray structure, used to upload data of any given vertex type to the GPU.
*/
struct VertexArray {

	private {

		GLuint vao_;
		GLuint vbo_;
		GLenum type_; //type of vertex data, GL_TRIANGLES etc
		uint num_vertices_;

	}

	@property GLuint handle() {
		return vao_;
	} //handle

	//@disable this(); maybe?
	@disable this(this);

	this(VertexType)(in VertexType[] vertices, GLenum draw_type = GL_STATIC_DRAW, Primitive type = Primitive.Triangles) nothrow @nogc {

		mixin("import " ~ VertexType.Imports ~ ";");
		this.num_vertices_ = cast(uint)vertices.length;
		this.type_ = type; //holla holla constant dollar

		glGenVertexArrays(1, &vao_);
		glBindVertexArray(vao_);

		glGenBuffers(1, &vbo_);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, GL_STATIC_DRAW);

		/* generate code from VertexSpec */
		import smidig.meta : PODMembers, MemberOffset, Symbol;

		enum V = VertexType();
		foreach (i, m; PODMembers!VertexType) {

			enum Member = Symbol!(V, m);
			enum OffsetOf = MemberOffset!(V, m);
			alias ElementType = Member._T;

			glEnableVertexAttribArray(i);
			glVertexAttribPointer(i,
					Member.sizeof / ElementType.sizeof,
					TypeToGLenum!ElementType,
					GL_FALSE, //TODO: handle normalization
					vertices[0].sizeof,
					cast(const(void)*)OffsetOf);

		}

		glBindVertexArray(0);

	} //this

	~this() nothrow @nogc {

		glDeleteVertexArrays(1, &vao_);

	} //~this

	void bind() nothrow @nogc {

		glBindVertexArray(vao_);

	} //bind

	void draw() nothrow @nogc {

		glDrawArrays(type_, 0, num_vertices_);

	} //draw

	/**
	 * Updates the vertex buffer's contents on the GPU side.
	*/
	void send(VertexType)(in VertexType[] vertices, GLenum draw_type = GL_DYNAMIC_DRAW) {

		bind();
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, draw_type);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
		unbind();

	} //send

	void unbind() nothrow @nogc {

		glBindVertexArray(0);

	} //unbind

} //VertexArray

struct ElementBuffer {

	GLuint ebo_;

	this(bool f) nothrow @nogc {

		glGenBuffers(1, &ebo_);

	} //this

	void bind() nothrow @nogc {

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ebo_);

	} //bind

	void send(VertexType)(in VertexType[] vertices, GLenum draw_type = GL_DYNAMIC_DRAW) {

		glBufferData(GL_ELEMENT_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, draw_type);

	} //send

	void unbind() nothrow @nogc {

		glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);

	} //unbind

} //ElementBuffer

@name("VertexArray 1")
unittest {

	alias TestVertex = VertexSpec!("gfm.math : Vector", Vec2f, "pos", Vec3f, "normal");
	TestVertex[] vertices;

	//auto verts = VertexArray(vertices);
	assert(0);

}

struct VertexBuffer {

	GLuint vbo_;

	@property GLuint handle() {
		return vbo_;
	} //handle

	~this() {

	} //~this

} //VertexBuffer

struct AttribLocation {

	this(GLuint offset, char[64] identifier) {
		this.offset = offset;
		this.identifier = identifier;
	}

	GLuint offset;
	char[64] identifier;

} //AttribLocation

struct Camera {

	Mat4f projection;
	Transform position;

} //Camera

/**
 * Structure representing a custom cursor.
*/
struct Cursor {

	VertexArray mesh;
	Shader* shader;
	Texture* texture;

	@disable this();
	@disable this(this);

	this(Texture* cursor_texture, Shader* cursor_shader) nothrow @nogc {

		this.texture = cursor_texture;
		int w = texture.width, h = texture.height;

		//cartesian coordinate system, inverted y component to not draw upside down.
		Vertex[6] vertices = createRectangleVec3f2f(w, h);
		this.mesh = VertexArray(vertices);
		this.shader = cursor_shader;

		//TODO move this part of the code out somewhere more logical
		import derelict.sdl2.sdl : SDL_ShowCursor, SDL_DISABLE;
		SDL_ShowCursor(SDL_DISABLE); //make sure to disable default cursor

	} //this

	void draw(ref Mat4f projection, Vec2f position) nothrow @nogc {

		auto tf = Transform(position);

		mesh.bind();
		shader.bind();
		texture.bind(0);
		shader.update(projection, tf);
		mesh.draw();
		texture.unbind();
		shader.unbind();
		mesh.unbind();

	} //draw

} //Cursor

/**
 * Represents an atlas for a given font, is also used to render text on screen.
*/
struct FontAtlas {

	import std.algorithm : max;
	import derelict.freetype.ft;

	import smidig.gl : RenderTarget;
	import smidig.memory : Mallocator, Region, makeArray, dispose;

	private struct CharacterInfo {

		float advance_x; // advance.x
		float advance_y; // advance.y

		float bitmap_width; // bitmap.width;
		float bitmap_height; // bitmap.rows;

		float bitmap_left; // bitmap_left;
		float bitmap_top; // bitmap_top;

		float tx_offset; // x offset of glyph in texture coordinates
		float tx_offset_y;

	} //CharacterInfo

	private {

		GLuint vao, vbo;
		Shader* shader;
		Texture atlas;

		CharacterInfo[96] chars;
		int atlas_width, atlas_height;
		int char_width_, char_height_;

		Region!Mallocator region_allocator_;

	}

	@property {

		int char_width() const { return char_width_; }
		int char_height() const { return char_height_; }

	}

	@disable this(this);

	this(in char[] font_name, uint font_size, Shader* text_shader) {

		this.region_allocator_ = Region!Mallocator(1024 * 8);
		this.shader = text_shader;

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);

		FT_Library ft;
		FT_Face face;

		if (FT_Init_FreeType(&ft)) { //TODO move this
			printf("[FontAtlas] Could not init freetype.");
		}

		if (FT_New_Face(ft, font_name.ptr, 0, &face)) {
			printf("[FontAtlas] Could not open font.");
		}

		scope(exit) {
			FT_Done_Face(face);
			FT_Done_FreeType(ft);
		}

		FT_Set_Pixel_Sizes(face, 0, font_size);
		FT_GlyphSlot glyph = face.glyph;

		int w = 0, h = 0;
		for (uint i = 32; i < 128; ++i) {

			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				printf("[FontAtlas] Character %c failed to load.", i);
				continue;
			}

			w += glyph.bitmap.width;
			h = max(h, glyph.bitmap.rows);

			this.atlas_width = w;
			this.atlas_height = h;

		}

		this.atlas = Texture(w, h, GL_RED, GL_RED, 1);
		this.atlas.bind(0);

		int x = 0; // current x position in the resulting texture to write to
		for (uint i = 32; i < 128; ++i) {

			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				continue;
			}

			float top_distance = face.glyph.metrics.horiBearingY; //used to adjust for eventual hang

			glTexSubImage2D(GL_TEXTURE_2D, 0, x, 0, glyph.bitmap.width, glyph.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, glyph.bitmap.buffer);

			int ci = i - 32;
			this.chars[ci].advance_x = glyph.advance.x >> 6;
			this.chars[ci].advance_y = glyph.advance.y >> 6;

			this.chars[ci].bitmap_width = glyph.bitmap.width;
			this.chars[ci].bitmap_height = glyph.bitmap.rows;

			this.chars[ci].bitmap_left = glyph.bitmap_left;
			this.chars[ci].bitmap_top = glyph.bitmap_top;

			this.chars[ci].tx_offset = cast(float)x / w;
			this.chars[ci].tx_offset_y = (top_distance/64 - (face.glyph.metrics.height>>6));

			x += glyph.bitmap.width; // adjust x position by the width of the current bitmap

		}

		// TODO find out what the 6 bits we shift out are and why we don't need them
		this.char_width_ = cast(typeof(char_width_))face.glyph.metrics.width >> 6;
		this.char_height_ = cast(typeof(char_height_))face.glyph.metrics.height >> 6;
		this.atlas.unbind();

	} //this

	~this() nothrow @nogc {

		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);

	} //~this

	void renderText(ref RenderTarget rt, in char[] text, float x, float y, float sx, float sy, int color) {

		struct Point {
			GLfloat x;
			GLfloat y;
			GLfloat s;
			GLfloat t;
		} //Point

		Point[] coords = region_allocator_.makeArray!Point(text.length * 6);
		scope(exit) { region_allocator_.deallocateAll(); } //pop it

		int n = 0; //used as the current index into coords
		foreach (ch; text) {

			if (ch < 32 || ch > 127) {
				continue;
			}

			int ci = ch - 32; //get char index
			float x2 =  x + chars[ci].bitmap_left * sx;
			float y2 = y + chars[ci].bitmap_top * sy;

			float w = chars[ci].bitmap_width * sx;
			float h = chars[ci].bitmap_height * sy;

			x += chars[ci].advance_x * sx;
			y += chars[ci].advance_y * sy;

			//adjust for hang
			y2 -= (chars[ci].bitmap_top * sy);
			y2 -= (chars[ci].tx_offset_y * sy);

			if (!w || !h) { //continue if no width or height, invisible character
				continue;
			}

			coords[n++] = Point(x2, y2, chars[ci].tx_offset, chars[ci].bitmap_height / atlas_height); //top left?
			coords[n++] = Point(x2, y2 - h, chars[ci].tx_offset, 0);

			coords[n++] = Point(x2 + w, y2, chars[ci].tx_offset + chars[ci].bitmap_width / atlas_width, chars[ci].bitmap_height / atlas_height);
			coords[n++] = Point(x2 + w, y2, chars[ci].tx_offset + chars[ci].bitmap_width / atlas_width, chars[ci].bitmap_height / atlas_height);

			coords[n++] = Point(x2, y2 - h, chars[ci].tx_offset, 0);
			coords[n++] = Point(x2 + w, y2 - h, chars[ci].tx_offset + chars[ci].bitmap_width / atlas_width, 0);

		}

		glEnable(GL_BLEND);
		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		atlas.bind(0);
		shader.bind();
		glBindVertexArray(vao);
		glEnableVertexAttribArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);

		GLfloat[4] col = to!GLColor(color);
		glUniform4fv(shader.bound_uniforms[0], 1, col.ptr);
		shader.update(rt.view_projection);

		glBufferData(GL_ARRAY_BUFFER, coords[0].sizeof * coords.length, coords.ptr, GL_DYNAMIC_DRAW);
		glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		glDrawArrays(GL_TRIANGLES, 0, n);

		glBindVertexArray(0);
		shader.unbind();
		atlas.unbind();

	} //renderText

} //FontAtlas

struct Text {

	import derelict.sdl2.sdl;
	import derelict.sdl2.ttf;

	private {

		enum MAX_SIZE = 64;
		char[MAX_SIZE] content;

		VertexArray mesh;
		Texture texture;
		Shader* shader;

	}

	@property int width() { return texture.width; }
	@property int height() { return texture.height; }

	@property ref char[MAX_SIZE] text() { return content; }
	@property void text(ref char[MAX_SIZE] new_text) { content = new_text[]; }

	this(TTF_Font* font, char[64] initial_text, int font_color, Shader* text_shader)  nothrow @nogc {

		this.content = initial_text;
		SDL_Color color = {cast(ubyte)(font_color>>16), cast(ubyte)(font_color>>8), cast(ubyte)(font_color)};
		SDL_Surface* surf = TTF_RenderUTF8_Blended(font, initial_text.ptr, color);
		scope(exit) SDL_FreeSurface(surf);

		this.texture = Texture(surf.pixels, surf.w, surf.h, GL_RGBA, GL_RGBA);
		int w = texture.width, h = texture.height;

		//cartesian coordinate system, inverted y component to not draw upside down.
		Vertex[6] vertices = createRectangleVec3f2f(w, h);
		this.mesh = VertexArray(vertices);
		this.shader = text_shader;

	} //this

	~this() {

	} //~this

	void draw(ref Mat4f projection, Vec2f position) nothrow @nogc {

		auto tf = Transform(position);

		mesh.bind();
		shader.bind();
		texture.bind(0);
		shader.update(projection, tf);
		mesh.draw();
		texture.unbind();
		shader.unbind();
		mesh.unbind();

	} //draw

} //Text

/**
 * Encapsulates a FrameBuffer, RenderBuffer, VertexArray, Texture and Shader for rendering to.
 */
struct RenderTarget {

	private {

		FrameBuffer fbo_;
		RenderBuffer rbo_;
		VertexArray quad_;
		Texture texture_;
		Shader* shader_;

		Mat4f view_projection_;
		Transform transform_;

	}

	@property nothrow @nogc {

		int width() const { return fbo_.width_; }
		int height() const { return fbo_.height_; }
		ref Mat4f projection() { return view_projection_; }
		ref Mat4f view_projection() { return view_projection_; }
		ref Transform transform() { return transform_; }

	}

	@disable this();
	@disable this(this);

	this(Shader* shader, int in_width, int in_height) {

		fbo_ = FrameBuffer(in_width, in_height);
		fbo_.bind(); //important

		rbo_ = RenderBuffer(fbo_);
		texture_ = Texture(null, in_width, in_height);
		auto quad_data = createRectangleVec3f2f(in_width, in_height);
		quad_ = VertexArray(quad_data);
		fbo_.attach_texbuffer(texture_);

		auto status = fbo_.check();
		assert(status == GL_FRAMEBUFFER_COMPLETE);
		shader_ = shader;

		//set up view projection and transform, height is flipped so tex coords make sense
		view_projection_ = Mat4f.orthographic(0.0f, in_width, 0.0f, in_height, 0.0f, 1.0f);
		transform_ = Transform(Vec2f(0, 0));

		fbo_.unbind();

	} //this

	void bind_fbo(int clear_colour = 0x428bca) {

		fbo_.bind();

		//clear fbo before drawing
		auto color = to!GLColor(clear_colour, 255);
		glClearColor(color[0], color[1], color[2], color[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, fbo_.width_, fbo_.height_);

	} //bind_fbo

	void unbind_fbo() {

		fbo_.unbind();

	} //unbind_fbo

	void resize(int w, int h) {


		auto verts = createRectangleVec3f2f(w, h);
		quad_.send(verts); //update mesh too!
		rbo_.resize(w, h);
		texture_.resize(w, h);
		fbo_.resize(w, h);

		view_projection_ = Mat4f.orthographic(0.0f, w, 0.0f, h, 0.0f, 1.0f);

	} //resize

	void draw() {

		bind();
		auto trans = transform_.transform;
		quad_.draw();
		unbind();

	} //draw

	void draw(Mat4f in_view_projection) {

		bind();
		auto trans = transform_.transform;
		shader_.update(in_view_projection, trans);
		quad_.draw();
		unbind();

	} //draw

	private {

		void bind() {

			quad_.bind();
			shader_.bind();
			texture_.bind(0);

		} //bind

		void unbind() {

			texture_.unbind();
			shader_.unbind();
			quad_.unbind();

		} //unbind

	}

} //RenderTarget

struct FrameBuffer {

	private {

		GLuint frame_buffer_;
		GLenum bound_target_;

		int width_;
		int height_;

	}

	@disable this();
	@disable this(this);

	this(int width, int height) {

		width_ = width;
		height_ = height;

		glGenFramebuffers(1, &frame_buffer_);

	} //this

	~this() {

		glDeleteFramebuffers(1, &frame_buffer_);

	} //~this

	/* for example attach_texbuffer(5, GL_COLOR_ATTACHMENT0); */
	void attach_texbuffer(GLuint texture_handle, GLenum type) {

		glFramebufferTexture2D(GL_FRAMEBUFFER, type, GL_TEXTURE_2D, texture_handle, 0);
		glDrawBuffers(1, &type); //FIXME: move this later

	} //attach_buffer

	void attach_texbuffer(ref Texture tex, GLenum type = GL_COLOR_ATTACHMENT0) {

		attach_texbuffer(tex.handle, type);

	} //attach_texbuffer

	void bind(GLenum target = GL_FRAMEBUFFER) {

		bound_target_ = target;
		glBindFramebuffer(bound_target_, frame_buffer_);

	} //bind

	GLuint check() {

		return glCheckFramebufferStatus(GL_FRAMEBUFFER);

	} //check

	void resize(int w, int h) {

		width_ = w;
		height_ = h;

	} //resize

	void unbind() {

		glBindFramebuffer(bound_target_, 0);
		bound_target_ = 0;

	} //unbind

} //FrameBuffer

struct RenderBuffer {

	GLuint render_buffer_;

	@disable this();
	@disable this(this);

	this(ref FrameBuffer fbo) {

		glGenRenderbuffers(1, &render_buffer_);
		glBindRenderbuffer(GL_RENDERBUFFER, render_buffer_);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, fbo.width_, fbo.height_);
		glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, render_buffer_);

	} //this

	~this() {

		glDeleteRenderbuffers(1, &render_buffer_);

	} //~this

	void resize(int w, int h) {

		bind();
		glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, w, h);
		unbind();

	} //resize

	void bind() {

		glBindRenderbuffer(GL_RENDERBUFFER, render_buffer_);

	} //bind

	void unbind() {

		glBindRenderbuffer(GL_RENDERBUFFER, 0);

	} //unbind

} //RenderBuffer

/**
 * Used to represent a batch of things from the same texture that will be drawn together,
 * for instance a texture-atlas backed tiled background, or a particle system.
*/
struct SpriteBatch(T) {

	import blindfire.engine.collections : Array;

	Array!T vertices_;
	VertexArray vao_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		vertices_ = typeof(vertices_)(allocator);
		vao_ = VertexArray(vertices_, GL_DYNAMIC_DRAW);

	} //this

	~this() {

	} //~this

	void add(T thing) {

		vertices_ ~= thing;

	} //add

	void clear() {

		vertices_.clear();
		vao_.send(vertices_, GL_DYNAMIC_DRAW);

	} //clear

	void draw(ref RenderTarget rt) {

		vao_.draw();

	} //draw

	void bind() {

		vao_.bind();

	} //bind

	void unbind() {

		vao_.unbind();

	} //unbind

} //SpriteBatch

/* Graph Structure */
/* - allows graphing a number of parameters over time, */
/*  for example frametimes/profiling results live. */
struct Graph {

} //Graph

struct Particle(V) {

	float lifetimes_;
	V velocities_;
	V positions_;

} //Particle

struct TestParticleSystem {

	import smidig.collections : ArraySOA;
	import smidig.memory : IAllocator;
	import smidig.math : Vec2f;

	GLuint vbo_;
	ArraySOA!(Particle!Vec2f) particles_;
	Texture* texture_;
	Shader shader_;
	VertexArray mesh_;

	Vec2f origin_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size = 32) {

		assert(allocator, "allocator was null?");

		particles_ = typeof(particles_)(allocator, initial_size);

		AttribLocation[3] attributes = [
			AttribLocation(0, "position"),
			AttribLocation(1, "tex_coord"),
			AttribLocation(2, "offset")
		];
		char[16][1] uniforms = ["view_projection"];
		shader_ = Shader("shaders/particle", attributes, uniforms);

		mesh_ = VertexArray(createRectangleVec3f2f(32, 32), GL_DYNAMIC_DRAW);

		glBindVertexArray(mesh_.vao_);

		glGenBuffers(1, &vbo_);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferData(GL_ARRAY_BUFFER, particles_.positions_.length * particles_.positions_[0].sizeof, particles_.positions_.ptr, GL_DYNAMIC_DRAW);

		glEnableVertexAttribArray(2);
		glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, cast(GLvoid*)0);
		glVertexAttribDivisor(2, 1); // set first vertex attrib to change every frame

		glBindVertexArray(0);

	} //this

	~this() {

		glDeleteBuffers(1, &vbo_);

	} //~this

	void config(Vec2f origin, float lifetime, size_t num_particles) {

		origin_ = origin;

		if (particles_.length != num_particles) {

			particles_.reserve(num_particles);
			particles_.length = num_particles;

		}

		with (particles_) {

			foreach (ref p; lifetimes_) {
				p = lifetime;
			}

			foreach (ref p; velocities_) {
				p = Vec2f(0, 0);
			}

			foreach (ref p; positions_) {
				p = origin_;
			}

			glBindVertexArray(mesh_.vao_);
			glBindBuffer(GL_ARRAY_BUFFER, vbo_);
			glBufferData(GL_ARRAY_BUFFER, positions_.length * positions_[0].sizeof, positions_.ptr, GL_DYNAMIC_DRAW);

		}

	} //config

	void tick(float dt, float drag) {

		import std.random;
		static Mt19937 gen;

		with (particles_) {

			foreach (i, ref p; lifetimes_) {

				if (p <= 0.0f) {
					positions_[i] = origin_;
					velocities_[i] = Vec2f(1.0f, 1.0f);
					p = 1.0f;
				}

				p = p - 0.15;

			}

			foreach (i, ref p; velocities_) {

				import smidig.math : normalize;

				p.x += normalize(cast(float)gen.front, cast(float)int.min, cast(float)int.max, 1.0f);
				p.y += normalize(cast(float)gen.front, cast(float)int.min, cast(float)int.max, 1.0f);
				p = p + drag;

			}

			foreach (i, ref p; positions_) {

				p = p + velocities_[i];

			}

			glBindVertexArray(mesh_.vao_);
			glBindBuffer(GL_ARRAY_BUFFER, vbo_);
			glBufferSubData(GL_ARRAY_BUFFER, cast(int*)0, positions_.length * positions_[0].sizeof, positions_.ptr);

		}

	} //tick

	void draw(ref Mat4f view_projection) {

		shader_.bind();
		texture_.bind(0);

		glUniformMatrix4fv(0, 1, GL_TRUE, view_projection.ptr);
		glBindVertexArray(mesh_.vao_);

		glDrawArraysInstanced(
				GL_TRIANGLES, 0, mesh_.num_vertices_, cast(int)particles_.positions_.length
				);

		glBindVertexArray(0);

	} //draw

} //TestParticleSystem

/**
 * Texture class, represents OpenGL textures in a easier to handle format.
 * Also allows loading of textures from file, or from a given buffer.
*/
struct Texture {

	import derelict.sdl2.sdl;
	import derelict.sdl2.image;

	private {

		GLuint texture_; //OpenGL handle for texture
		GLenum input_format_, output_format_, data_type_;
		int width_, height_;

	}

	@property @nogc nothrow {

		int width() const { return width_; }
		int height() const { return height_; }
		GLuint handle() { return texture_; }

	}

	@disable this(this);

	this(in char[] file_name) {

		//SDL_Surface struct
		// int w, h (width/height)
		// SDL_PixelFormat* format (actual image format)
		// void* pixels (pointer to pixel data)
		SDL_Surface* image = IMG_Load(file_name.ptr);
		scope(exit) SDL_FreeSurface(image);

		if (image == null) {
			printf("[OpenGL] Failed to load texture %s : %s", file_name.ptr, IMG_GetError());
		}

		this(image.pixels, image.w, image.h, GL_RGBA, GL_RGBA);

	} //this

	this(int width, int height, GLenum input_format, GLenum output_format, GLenum unpack_alignment) nothrow @nogc {

		width_ = width;
		height_ = height;
		input_format_ = input_format;
		output_format_ = output_format;
		data_type_ = GL_UNSIGNED_BYTE;

		glGenTextures(1, &texture_);
		glBindTexture(GL_TEXTURE_2D, texture_);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glPixelStorei(GL_UNPACK_ALIGNMENT, unpack_alignment);
		glTexImage2D(GL_TEXTURE_2D, 0, input_format_, width_, height_, 0, output_format_, GL_UNSIGNED_BYTE, cast(void*)0);

		glBindTexture(GL_TEXTURE_2D, 0);

	} //this

	this(void* pixels, int width, int height, GLenum input_format = GL_RGBA, GLenum output_format = GL_RGBA, GLenum data_type = GL_UNSIGNED_BYTE) nothrow @nogc {

		width_ = width;
		height_ = height;
		input_format_ = input_format;
		output_format_ = output_format;
		data_type_ = data_type;

		//generate single texture, put handle in texture
		glGenTextures(1, &texture_);

		//normal 2d texture, bind to our texture handle
		glBindTexture(GL_TEXTURE_2D, texture_);

		//set texture parameters in currently bound texture, controls texture wrapping (or GL_CLAMP?)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		//linearly interpolate between pixels, MIN if texture is too small for drawing area, MAG if drawing area is smaller than texture
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		//texture type, level, format to store as, width, height, border, format loaded in
		glTexImage2D(GL_TEXTURE_2D, 0, input_format_, width_, height_, 0, output_format_, data_type_, pixels);

		//UNBIND
		glBindTexture(GL_TEXTURE_2D, 0);

	} //this

	~this() nothrow @nogc {

		glDeleteTextures(1, &texture_);

	} //~this

	/**
	 * Binds the texture handle, takes an argument for which texture unit to use.
	*/
	void bind(int unit) nothrow @nogc {

		assert(unit >= 0 && unit <= 31);
		glActiveTexture(GL_TEXTURE0 + unit); //since this is sequential, this works
		glBindTexture(GL_TEXTURE_2D, texture_);

	} //bind

	void unbind() nothrow @nogc {

		glBindTexture(GL_TEXTURE_2D, 0);

	} //unbind

	/**
	 * Updates the texture in place given the new texture buffer.
	 * Takes an optional offset to update only a part of the texture.
	 **/
	void update(void[] pixels, size_t offset = 0) nothrow @nogc {

		bind(0);
		glBufferSubData(GL_ARRAY_BUFFER, cast(GLintptr)offset, pixels.length, pixels.ptr);
		unbind();

	} //update

	/**
	 * Resizes the texture.
	 **/
	void resize(int w, int h, void* data = null) nothrow @nogc {

		width_ = w;
		height_ = h;

		bind(0);
		glTexImage2D(GL_TEXTURE_2D, 0, input_format_, width_, height_, 0, output_format_, data_type_, data);
		unbind();

	} //resize

} //Texture

/**
 * Represents a position, rotation and scale in space, with an optional origin modifier for rotations.
*/
struct Transform {

	Vec2f position;
	Vec3f rotation;
	Vec2f scale;

	Vec3f origin;

	this(in Vec2f pos, in Vec3f rotation = Vec3f(0.0f, 0.0f, 0.0f), in Vec2f scale = Vec2f(1.0f, 1.0f)) nothrow @nogc {
		this.position = pos;
		this.rotation = rotation;
		this.scale = scale;
		this.origin = Vec3f(0.0f, 0.0f, 0.0f);
	} //this

	@property Mat4f transform() const nothrow @nogc {

		Mat4f originMatrix = Mat4f.translation(origin);
		Mat4f posMatrix = Mat4f.translation(Vec3f(position, 0.0f) - origin);

		Mat4f rotXMatrix = Mat4f.rotation(rotation.x, Vec3f(1, 0, 0));
		Mat4f rotYMatrix = Mat4f.rotation(rotation.y, Vec3f(0, 1, 0));
		Mat4f rotZMatrix = Mat4f.rotation(rotation.z, Vec3f(0, 0, 1));
		Mat4f scaleMatrix = Mat4f.scaling(Vec3f(scale, 1.0f));

		Mat4f rotMatrix = rotXMatrix * rotYMatrix * rotZMatrix;

		return posMatrix * rotMatrix * originMatrix * scaleMatrix;

	} //transform

} //Transform

struct Vertex {

	enum Imports = "gfm.math : Vector";

	Vec3f pos;
	Vec2f tex_coord;

	this(in Vec3f pos, in Vec2f tex_coord) nothrow @nogc pure {
		this.pos = pos;
		this.tex_coord = tex_coord;
	}

} //Vertex

template isVertexType(T) {
	enum isVertexType =  __traits(compiles, T.Imports);
} //isVertexType

/* UDA's for members in VertexSpecs */
struct _AttribDivisor {

	uint index;
	uint divisor;

} //_AttribDivisor

@property divisor(uint index, uint divisor) {

	return _AttribDivisor(index, divisor);

} //divisor

enum normalized = "normalized";

version (unittest) {

	struct TestVertex {

		enum Imports = "gfm.math : Vector";

		Vec3f position;
		Vec2f tex_coord;
		@divisor(2, 1) Vec2f offset;

	}

}

struct VertexSpec(string imprt, T...) {

	alias Imports = imprt;
	alias Members = T;
	mixin("import " ~ imprt ~ ";"); 

	static assert(T.length % 2 == 0, "length % 2 must be 0, arguments to come in pairs of member type, member name");

	static template generateMembers(T...) {

		import std.format : format;

		static if (T.length >= 2) {
			enum generateMembers = q{%s %s;}.format(T[0].stringof, T[1]) ~ generateMembers!(T[2..$]);
		} else {
			enum generateMembers = "";
		}

	} //generateMembers

	mixin(generateMembers!T);

} //VertexSpec

@name("VertexSpec 1")
unittest {

	import smidig.math : Vec2f, Vec3f;

	auto test_vertex = VertexSpec!("gfm.math : Vector", Vec2f, "pos", Vec3f, "normal")();
	test_vertex.pos = Vec2f(5.0, 5.0);
	test_vertex.normal = Vec3f(1.0, 2.0, 3.0);

}

/**
 * OpenGL shader class meant to safely represent what
 * attributes/uniforms it takes, so it can be verified
 * at compile time that these are correct.
*/
struct SafeShader(AttribLocation[] attribs, string[] uniforms) {

	static template makeAttribs() {

	} //makeAttribs

	static template makeUniforms() {

	} //makeUniforms

	GLuint program_;

	@disable this();
	@disable this(this);

	@property GLuint handle() {
		return program_;
	} //handle

	this(in char* file_name) {

	} //this

	~this() {

	} //~this

	/**
	 * Reloads the shader from file and recompiles it.
	*/
	void reload() {

	} //reload

	/**
	 * Reloads the shader, loading data from a given null-terminated char buffer instead,
	 * then recompiles it.
	*/
	void reload(in char[] data) {

	} //reload

	void bind() {

		glUseProgram(program_);

	} //bind

	void unbind() {

		glUseProgram(0);

	} //unbind

	/**
	 * Send data to given uniform for shader, if bound.
	*/
	void setUniform(U, T)(U uniform, in T value) {

	} //setUniform

} //SafeShader

version (unittest) {

	alias BasicShader = SafeShader!(
		[AttribLocation(0, "position"), 
		AttribLocation(1, "tex_coord")],
		["transform", "perspective"]);

	//auto shader = BasicShader("shaders/basic");

}

unittest {

}

struct Shader {

	//the shader program
	GLuint program;

	//uniforms
	GLuint[4] bound_uniforms;

	@disable this();
	@disable this(this);

	@property GLuint handle() {
		return program;
	} //handle

	this(in char[] file_name, in AttribLocation[] attribs, in char[16][] uniforms) {

		assert(uniforms.length < bound_uniforms.length);

		import smidig.util : cformat;

		char[256] fn_buff; //FIXME: AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA

		StringBuffer vs = loadShader(cformat(fn_buff, "%s.vs", file_name.ptr));
		StringBuffer fs = loadShader(cformat(fn_buff, "%s.fs", file_name.ptr));

		auto c_vs = vs.c_str();
		auto c_fs = fs.c_str();

		//delegate construction
		this(&c_vs, &c_fs, file_name, attribs, uniforms);

	} //this

	this(in char** vs_data, in char** fs_data, in char[] file_name, in AttribLocation[] attribs, in char[16][] uniforms) {

		assert(uniforms.length < bound_uniforms.length);

		GLuint vshader = compileShader(vs_data, GL_VERTEX_SHADER, file_name);
		GLuint fshader = compileShader(fs_data, GL_FRAGMENT_SHADER, file_name);

		GLuint[2] shaders = [vshader, fshader];
		program = createShaderProgram(shaders, attribs);

		foreach (i, uniform; uniforms) {
			auto res = glGetUniformLocation(program, uniform.ptr);
			if (res == -1) {
				import smidig.util : tempformat;
				auto str = tempformat!256("%s doesn't exist?", uniform.ptr);
				assert(res != -1, str);
			}
			bound_uniforms[i] = res;
		}

		glDetachShader(program, vshader);
		glDetachShader(program, fshader);
		glDeleteShader(vshader);
		glDeleteShader(fshader);

	} //this

	~this() nothrow @nogc {

		glDeleteProgram(program);

	} //~this

	void update(ref Mat4f projection, ref Transform transform) nothrow @nogc {

		Mat4f model = transform.transform;

		//transpose matrix, since row major, not column
		glUniformMatrix4fv(bound_uniforms[0], 1, GL_TRUE, model.ptr);
		glUniformMatrix4fv(bound_uniforms[1], 1, GL_TRUE, projection.ptr);

	} //update

	void update(ref Mat4f projection, ref Mat4f transform) nothrow @nogc {

		//transpose matrix, since row major, not column
		glUniformMatrix4fv(bound_uniforms[0], 1, GL_TRUE, transform.ptr);
		glUniformMatrix4fv(bound_uniforms[1], 1, GL_TRUE, projection.ptr);

	} //update

	void update(ref Mat4f projection) nothrow @nogc {

		glUniformMatrix4fv(bound_uniforms[1], 1, GL_TRUE, projection.ptr);

	} //update

	void update(ref Transform trans) nothrow @nogc {

		auto transf = trans.transform;
		glUniformMatrix4fv(bound_uniforms[0], 1, GL_TRUE, transf.ptr);

	} //update

	void bind() nothrow @nogc {

		glUseProgram(program);

	} //bind

	void unbind() nothrow @nogc {

		glUseProgram(0);

	} //unbind

} //Shader

//C-ish code ahoy
StringBuffer loadShader(in char[] file_name) {

	import smidig.file : readFile;
	return readFile(file_name);

} //loadShader

bool checkShaderError(GLuint shader, GLuint flag, bool is_program, in char[] shader_path) nothrow {

	GLint result;

	(is_program) ? glGetProgramiv(shader, flag, &result)
		: glGetShaderiv(shader, flag, &result);

	if (result == GL_FALSE) {

		GLchar[256] log; //FIXME this is potentially fatal
		(is_program) ? glGetProgramInfoLog(shader, log.sizeof, null, log.ptr)
			: glGetShaderInfoLog(shader, log.sizeof, null, log.ptr);

		printf("[OpenGL] Error in %s: %s\n", shader_path.ptr, log.ptr);
		return false;

	}

	return true;

} //checkShaderError

GLuint compileShader(const(GLchar*)* shader_source, GLenum shader_type, in char[] shader_path) nothrow {

	GLuint new_shader = glCreateShader(shader_type);
	glShaderSource(new_shader, 1, shader_source, null);
	glCompileShader(new_shader);

	if (!checkShaderError(new_shader, GL_COMPILE_STATUS, false, shader_path)) {
		glDeleteShader(new_shader);
		return 0;
	}

	return new_shader;

} //compileShader

GLuint createShaderProgram(in GLuint[] shaders, in AttribLocation[] attribs) nothrow {

	GLuint program = glCreateProgram();

	foreach(shader; shaders) {
		glAttachShader(program, shader);
	}

	foreach (ref attr; attribs) {
		glBindAttribLocation(program, attr.offset, attr.identifier.ptr);
	}

	glLinkProgram(program);
	if (!checkShaderError(program, GL_LINK_STATUS, true, "")) {
		glDeleteShader(program);
		return 0;
	}

	glValidateProgram(program);
	if (!checkShaderError(program, GL_VALIDATE_STATUS, true, "")) {
		glDeleteShader(program);
		return 0;
	}

	return program;

} //createShaderProgram

/**
 * Converts an integer representing a colour, for example 0x428bca into a 4 element
 * int array for passing to OpenGL.
*/
GLfloat[4] to(T : GLfloat[4])(int color, ubyte alpha = 255) nothrow @nogc pure {

	GLfloat[4] gl_color = [ //mask out r, g, b components from int
		cast(float)cast(ubyte)(color>>16)/255,
		cast(float)cast(ubyte)(color>>8)/255,
		cast(float)cast(ubyte)(color)/255,
		cast(float)cast(ubyte)(alpha)/255
	];

	return gl_color;

} //to!GLfloat[4]

/**
 * Converts a GLenum representation of a value to a c string representation,
 * for use with debug printing of OpenGL info, from debug callbacks for example.
*/
const (char*) to(T : char*)(GLenum value) {

	switch (value) {

		// sources
		case GL_DEBUG_SOURCE_API: return "API";
		case GL_DEBUG_SOURCE_WINDOW_SYSTEM: return "Window System";
		case GL_DEBUG_SOURCE_SHADER_COMPILER: return "Shader Compiler";
		case GL_DEBUG_SOURCE_THIRD_PARTY: return "Third Party";
		case GL_DEBUG_SOURCE_APPLICATION: return "Application";
		case GL_DEBUG_SOURCE_OTHER: return "Other";

		// error types
		case GL_DEBUG_TYPE_ERROR: return "Error";
		case GL_DEBUG_TYPE_DEPRECATED_BEHAVIOR: return "Deprecated Behaviour";
		case GL_DEBUG_TYPE_UNDEFINED_BEHAVIOR: return "Undefined Behaviour";
		case GL_DEBUG_TYPE_PORTABILITY: return "Portability";
		case GL_DEBUG_TYPE_PERFORMANCE: return "Performance";
		case GL_DEBUG_TYPE_MARKER: return "Marker";
		case GL_DEBUG_TYPE_PUSH_GROUP: return "Push Group";
		case GL_DEBUG_TYPE_POP_GROUP: return "Pop Group";
		case GL_DEBUG_TYPE_OTHER: return "Other";

		// severity markers
		case GL_DEBUG_SEVERITY_HIGH: return "High";
		case GL_DEBUG_SEVERITY_MEDIUM: return "Medium";
		case GL_DEBUG_SEVERITY_LOW: return "Low";
		case GL_DEBUG_SEVERITY_NOTIFICATION: return "Notification";

		default: return "(undefined)";

	}

} //to!string(GLenum)

int darken(int color, uint percentage) nothrow @nogc pure {

	uint adjustment = 255 / percentage;
	ubyte r = cast(ubyte)(color>>16);
	ubyte g = cast(ubyte)(color>>8);
	ubyte b = cast(ubyte)(color);
	r -= adjustment;
	g -= adjustment;
	b -= adjustment;
	int result = (r << 16) | (g << 8) | b;

	return result;

} //darken

/* Primitives? */

auto createRectangleVec3f(float w, float h) nothrow @nogc pure {

	Vec3f[6] vertices = [
		Vec3f(0.0f, 0.0f, 0.0f), // top left
		Vec3f(w, 0.0f, 0.0f), // top right
		Vec3f(w, h, 0.0f), // bottom right

		Vec3f(0.0f, 0.0f, 0.0f), // top left
		Vec3f(0.0f, h, 0.0f), // bottom left
		Vec3f(w, h, 0.0f) // bottom right
	];

	return vertices;

} //createRectangleVec3f

auto createRectangleVec3f2f(float w, float h) nothrow @nogc pure {

	Vertex[6] vertices = [
		Vertex(Vec3f(0.0f, 0.0f, 0.0f), Vec2f(0.0f, 0.0f)), // top left
		Vertex(Vec3f(w, 0.0f, 0.0f), Vec2f(1.0f, 0.0f)), // top right
		Vertex(Vec3f(w, h, 0.0f), Vec2f(1.0f, 1.0f)), // bottom right

		Vertex(Vec3f(0.0f, 0.0f, 0.0f), Vec2f(0.0f, 0.0f)), // top left
		Vertex(Vec3f(0.0f, h, 0.0f), Vec2f(0.0f, 1.0f)), // bottom left
		Vertex(Vec3f(w, h, 0.0f), Vec2f(1.0f, 1.0f)) // bottom right
	];

	return vertices;

} //createRectangleVec3f2f

/**
 * Draws a line, uses the shader from the RenderTarget currently, also
 * creates a new buffer on every frame for whats to be drawn, probably
 * not the greatest idea ever.
*/
void drawLine(T)(ref RenderTarget rt, in T[] positions) {

	auto va = VertexArray(positions, GL_DYNAMIC_DRAW, GL_LINES);

	va.bind();
	rt.shader_.bind();

	rt.shader_.update(rt.projection, rt.transform);
	va.draw();

	rt.shader_.unbind();
	va.unbind();

} //drawLine
