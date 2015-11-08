module smidig.gl;

import core.stdc.stdio : printf;
import std.stdio : writefln;

import derelict.opengl3.gl3;

import smidig.math : Vec2i, Vec2f, Vec3f, Mat3f, Mat4f;
import smidig.collections : StringBuffer;

alias GLColor = GLfloat[4];

mixin template OpenGLError() {

	invariant {

		GLenum status = glGetError();
		if (status != GL_NO_ERROR) {
			writefln("[OpenGL : %s] Error: %d", typeof(this).stringof, status);
		}

	}

} //OpenGLError

struct VertexArray {

	GLuint vao_;
	GLenum type_; //type of vertex data, GL_TRIANGLES etc
	uint num_vertices_;

	@property GLuint handle() {
		return vao_;
	} //handle

	this(VertexType)(in VertexType[] vertices) {

		//generate calls depending on vertex specification

	} //this

	~this() {

		glDeleteVertexArrays(1, &vao_);

	} //~this

	void bind() {

		glBindVertexArray(vao_);

	} //bind

	void draw() {

		glDrawArrays(type_, 0, num_vertices_);

	} //draw

	void unbind()  {

		glBindVertexArray(0);

	} //unbind

} //VertexArray

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

struct Cursor {

	Mesh mesh;
	Shader* shader;
	Texture* texture;
	
	@disable this();
	@disable this(this);

	this(Texture* cursor_texture, Shader* cursor_shader) nothrow @nogc {

		this.texture = cursor_texture;
		int w = texture.width, h = texture.height;

		//cartesian coordinate system, inverted y component to not draw upside down.
		Vertex[6] vertices = createRectangleVec3f2f(w, h);
		this.mesh = Mesh(vertices);
		this.shader = cursor_shader;

		import derelict.sdl2.sdl : SDL_ShowCursor, SDL_DISABLE;
		SDL_ShowCursor(SDL_DISABLE); //make sure to disable default cursor

	} //this

	void draw(ref Mat4f projection, Vec2f position) nothrow @nogc {
		
		auto tf = Transform(position);

		shader.bind();
		texture.bind(0);
		shader.update(projection, tf);
		mesh.draw();
		texture.unbind();
		shader.unbind();

	} //draw

} //Cursor

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

struct FontAtlas {

	import std.algorithm : max;

	import derelict.freetype.ft;

	import smidig.window : Window;
	import smidig.memory : Mallocator, Region, makeArray, dispose;

	private {

		GLuint vao, vbo;
		Shader* shader;
		Texture atlas;

		CharacterInfo[96] characters;
		int atlas_width, atlas_height;
		int char_width_, char_height_;

		Region!Mallocator region_allocator_;

	}

	@property int char_width() const { return char_width_; }
	@property int char_height() const { return char_height_; }

	@disable this(this);

	this(in char[] font_name, uint font_size, Shader* text_shader) {

		this.region_allocator_ = Region!Mallocator(1024 * 8);
		this.shader = text_shader;

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);

		FT_Library ft;
		FT_Face face;

		if (FT_Init_FreeType(&ft)) {
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

		int x = 0;
		for (uint i = 32; i < 128; ++i) {

			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				continue;
			}

			float top_distance = face.glyph.metrics.horiBearingY; //used to adjust for eventual hang

			glTexSubImage2D(GL_TEXTURE_2D, 0, x, 0, glyph.bitmap.width, glyph.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, glyph.bitmap.buffer);

			int ci = i - 32;
			this.characters[ci].advance_x = glyph.advance.x >> 6;
			this.characters[ci].advance_y = glyph.advance.y >> 6;

			this.characters[ci].bitmap_width = glyph.bitmap.width;
			this.characters[ci].bitmap_height = glyph.bitmap.rows;

			this.characters[ci].bitmap_left = glyph.bitmap_left;
			this.characters[ci].bitmap_top = glyph.bitmap_top;

			this.characters[ci].tx_offset = cast(float)x / w;
			this.characters[ci].tx_offset_y = (top_distance/64 - (face.glyph.metrics.height>>6));

			x += glyph.bitmap.width;

		}

		this.char_width_ = cast(typeof(char_width_))face.glyph.metrics.width >> 6;
		this.char_height_ = cast(typeof(char_height_))face.glyph.metrics.height >> 6;
		this.atlas.unbind();

	} //this

	~this() nothrow @nogc {
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
	} //~this

	void renderText(Window* window, in char[] text, float x, float y, float sx, float sy, int color) {

		struct Point {
			GLfloat x;
			GLfloat y;
			GLfloat s;
			GLfloat t;
		} //Point

		Point[] coords = region_allocator_.makeArray!Point(text.length * 6);
		scope(exit) { region_allocator_.deallocateAll(); } //pop it

		int n = 0; //how many to draw?
		foreach (ch; text) {

			if (ch < 32 || ch > 127) {
				continue;
			}

			int ci = ch - 32; //get char index
			float x2 =  x + characters[ci].bitmap_left * sx;
			float y2 = y + characters[ci].bitmap_top * sy;

			float w = characters[ci].bitmap_width * sx;
			float h = characters[ci].bitmap_height * sy;

			x += characters[ci].advance_x * sx;
			y += characters[ci].advance_y * sy;

			//adjust for hang
			y2 -= (characters[ci].bitmap_top * sy);
			y2 -= (characters[ci].tx_offset_y * sy);

			if (!w || !h) { //continue if no width or height, invisible character
			 	continue;
			}

			coords[n++] = Point(x2, y2, characters[ci].tx_offset, characters[ci].bitmap_height / atlas_height); //top left?
			coords[n++] = Point(x2, y2 - h, characters[ci].tx_offset, 0);

			coords[n++] = Point(x2 + w, y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, characters[ci].bitmap_height / atlas_height);
			coords[n++] = Point(x2 + w, y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, characters[ci].bitmap_height / atlas_height);

			coords[n++] = Point(x2, y2 - h, characters[ci].tx_offset, 0);
			coords[n++] = Point(x2 + w, y2 - h, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, 0);

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
		shader.update(window.view_projection);

		glBufferData(GL_ARRAY_BUFFER, coords[0].sizeof * coords.length, coords.ptr, GL_DYNAMIC_DRAW);
		glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		glDrawArrays(GL_TRIANGLES, 0, n);

		glBindVertexArray(0);
		shader.unbind();
		atlas.unbind();

	} //renderText

	mixin OpenGLError;

} //FontAtlas


struct Text {

	import derelict.sdl2.sdl;
	import derelict.sdl2.ttf;

	private {

		enum MAX_SIZE = 64;
		char[MAX_SIZE] content;

		Mesh mesh;
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
		this.mesh = Mesh(vertices);
		this.shader = text_shader;
	
	} //this

	~this() {

	} //~this

	void draw(ref Mat4f projection, Vec2f position) nothrow @nogc {

		auto tf = Transform(position);

		shader.bind();
		texture.bind(0);
		shader.update(projection, tf);
		mesh.draw();
		texture.unbind();
		shader.unbind();

	} //draw

	mixin OpenGLError;

} //Text

struct Mesh {

	enum {
		POSITION_VB,
		NUM_BUFFERS
	}

	GLuint vao; //vertex array object
	GLuint[NUM_BUFFERS] vbo; //vertex array buffers
	uint draw_count;

	@disable this(this);

	this(in Vertex[] vertices) nothrow @nogc {

		this.draw_count = cast(uint)vertices.length;

		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		//create NUM_BUFFERS
		glGenBuffers(NUM_BUFFERS, vbo.ptr);

		//vertex position buffer
		glBindBuffer(GL_ARRAY_BUFFER, vbo[POSITION_VB]); //tells OpenGL to interpret this as an array 
		glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, GL_STATIC_DRAW);
		//upload to GPU, send size in bytes and pointer to array, also tell GPU it will never be modified

		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vertices[0].sizeof, cast(const(void)*)null);
		//0 corresponds to previous attribarray, 3 is number of elements in vertex, set type to float (don't normalize(GL_FALSE))
		// bytes to skip to find the next attribute, byte offset from beginning to find the first attribute
		// use sizeof of tex_coord as stride

		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, vertices[0].sizeof, cast(const(void)*)vertices[0].pos.sizeof);

		//UNBIND
		glBindVertexArray(0); //unbind

	} //this

	~this() nothrow @nogc {

		glDeleteVertexArrays(1, &vao);

	} //~this

	void draw() nothrow @nogc {

		glBindVertexArray(vao); //set vertex array to use

		glDrawArrays(GL_TRIANGLES, 0, draw_count); //read from beginning (offset is 0), draw draw_count vertices

		glBindVertexArray(0); //unbind

	} //draw

	mixin OpenGLError;

} //Mesh

struct FrameBuffer {

	GLuint frame_buffer_;
	GLenum bound_target_;

	@disable this();
	@disable this(this);

	this(int width, int height) {

		glGenFramebuffers(1, &frame_buffer_);
		glFramebufferParameteri(bound_target_, GL_FRAMEBUFFER_DEFAULT_WIDTH, width);
		glFramebufferParameteri(bound_target_, GL_FRAMEBUFFER_DEFAULT_HEIGHT, height);

	} //this

	~this() {

		glDeleteFramebuffers(1, &frame_buffer_);

	} //~this

	/* for example attach_texbuffer(5, GL_COLOR_ATTACHMENT0); */
	void attach_texbuffer(GLuint texture_handle, GLenum type) {

		glFramebufferTexture2D(GL_FRAMEBUFFER, type, GL_TEXTURE_2D, texture_handle, 0);

	} //attach_buffer

	void bind(GLenum target) {

		bound_target_ = target;
		glBindFramebuffer(bound_target_, frame_buffer_);

	} //bind

	void unbind() {

		bound_target_ = 0;
		glBindFramebuffer(bound_target_, 0);

	} //unbind

	mixin OpenGLError;

} //FrameBuffer

struct RenderBuffer {

	GLuint render_buffer_;

	@disable this();
	@disable this(this);

	this(ref FrameBuffer fbo, GLsizei width, GLsizei height) {

		glGenRenderbuffers(1, &render_buffer_);
		glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA, width, height);

	} //this

	~this() {

		glDeleteRenderbuffers(1, &render_buffer_);

	} //~this

	void bind() {

		glBindRenderbuffer(GL_RENDERBUFFER, render_buffer_);

	} //bind

	void unbind() {

		glBindRenderbuffer(GL_RENDERBUFFER, 0);

	} //unbind

	mixin OpenGLError;

} //RenderBuffer

/* Graph Structure */
/* - allows graphing a number of parameters over time, */
/*  for example frametimes/profiling results live. */
struct Graph {

} //Graph

struct Particle(V) {

	V position_;
	V velocity_;

	void tick(float drag) {

		position_ += velocity_;
		velocity_ -= drag;

	} //simulate

} //Particle

struct ParticleSystem(V) {

	import smidig.memory : IAllocator;
	import smidig.collections : Array;

	Mesh* mesh_;
	Shader* shader_;
	Texture* texture_;

	V origin_;
	V orientation_;

	IAllocator allocator_;
	Array!(Particle!V) particles_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator, Mesh* mesh, Shader* shader, Texture* texture, V origin, V orientation, size_t initial_size) {

		this.mesh_ = mesh;
		this.shader_ = shader;
		this.texture_ = texture;

		this.origin_ = origin;
		this.orientation_ = orientation;

		this.allocator_ = allocator;
		this.particles_ = typeof(particles_)(allocator, initial_size);

	} //this

	void initialize() {

	} //initialize

	~this() {

	} //~this

	void fire(size_t particles) {

	} //fire

	void tick() {

		enum drag = 32.0f;

		foreach (ref p; particles_) {
			p.tick(drag);
		}

	} //tick

	void draw() {

		shader_.bind();
		texture_.bind(0);
		//draw instanced shit here :))))

	} //draw

	mixin OpenGLError;

} //ParticleSystem

unittest {

	import smidig.math : Vec2f;
	import smidig.memory : theAllocator;

	auto origin = Vec2f(0, 0);
	auto orientation = Vec2f(0, 1);

	auto part_sys = ParticleSystem!Vec2f(theAllocator, null, null, null, origin, orientation, 32);

}

struct TestParticleSystem {

	import smidig.collections : Array;
	import smidig.memory : IAllocator;
	import smidig.math : Vec2f;

	GLuint vbo_;
	Array!float lifetimes_;
	Array!Vec2f velocities_;
	Array!Vec2f positions_;
	Texture* texture_;
	Shader shader_;
	Mesh mesh_;

	Vec2f origin_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size = 32) {

		lifetimes_ = typeof(lifetimes_)(allocator, initial_size);
		velocities_ = typeof(velocities_)(allocator, initial_size);
		positions_ = typeof(positions_)(allocator, initial_size);

		AttribLocation[3] attributes = [
			AttribLocation(0, "position"),
			AttribLocation(1, "tex_coord"),
			AttribLocation(2, "offset")
		];
		char[16][1] uniforms = ["view_projection"];
		shader_ = Shader("shaders/particle", attributes, uniforms);

		mesh_ = Mesh(createRectangleVec3f2f(32, 32));

		glBindVertexArray(mesh_.vao);

		glGenBuffers(1, &vbo_);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferData(GL_ARRAY_BUFFER, positions_.length * positions_[0].sizeof, positions_.ptr, GL_DYNAMIC_DRAW);

		glEnableVertexAttribArray(2);
		glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, cast(GLvoid*)0);
		glVertexAttribDivisor(2, 1); //set first vertex attrib to change every time

		glBindVertexArray(0);

	} //this

	~this() {

		glDeleteBuffers(1, &vbo_);

	} //~this

	void config(Vec2f origin, float lifetime, size_t num_particles) {

		origin_ = origin;

		if (positions_.length != num_particles) {

			velocities_.reserve(num_particles);
			velocities_.length = num_particles;

			lifetimes_.reserve(num_particles);
			lifetimes_.length = num_particles;

			positions_.reserve(num_particles);
			positions_.length = num_particles;

		}

		foreach (ref p; lifetimes_) {
			p = lifetime;
		}

		foreach (ref p; velocities_) {
			p = Vec2f(0, 0);
		}

		foreach (ref p; positions_) {
			p = origin_;
		}

		glBindVertexArray(mesh_.vao);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferData(GL_ARRAY_BUFFER, positions_.length * positions_[0].sizeof, positions_.ptr, GL_DYNAMIC_DRAW);

	} //config

	void tick(float dt, float drag) {

		import std.random;
		static Mt19937 gen;

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

		glBindVertexArray(mesh_.vao);
		glBindBuffer(GL_ARRAY_BUFFER, vbo_);
		glBufferSubData(GL_ARRAY_BUFFER, cast(int*)0, positions_.length * positions_[0].sizeof, positions_.ptr);

	} //tick

	void draw(ref Mat4f view_projection) {

		shader_.bind();
		texture_.bind(0);

		glUniformMatrix4fv(shader_.bound_uniforms[0], 1, GL_TRUE, view_projection.ptr);
		glBindVertexArray(mesh_.vao);

		glDrawArraysInstanced(
			GL_TRIANGLES, 0, mesh_.draw_count, cast(int)positions_.length
		);

		glBindVertexArray(0);

	} //draw

	mixin OpenGLError;

} //TestParticleSystem

//use SDL2 for loading textures, since we're already using it for windowing.
struct Texture {

	import derelict.sdl2.sdl;
	import derelict.sdl2.image;

	GLuint texture; //OpenGL handle for texture
	int width, height;

	@disable this(this);

	@property GLuint handle() {
		return texture;
	} //handle

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

		this.width = width;
		this.height = height;

		glGenTextures(1, &this.texture);
		glBindTexture(GL_TEXTURE_2D, this.texture);
		
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		glPixelStorei(GL_UNPACK_ALIGNMENT, unpack_alignment);
		glTexImage2D(GL_TEXTURE_2D, 0, input_format, width, height, 0, output_format, GL_UNSIGNED_BYTE, cast(void*)0);

		glBindTexture(GL_TEXTURE_2D, 0);

	} //this

	this(void* pixels, int width, int height, GLenum input_format, GLenum output_format) nothrow @nogc {

		this.width = width;
		this.height = height;
	
		//generate single texture, put handle in texture
		glGenTextures(1, &this.texture);

		//normal 2d texture, bind to our texture handle
		glBindTexture(GL_TEXTURE_2D, this.texture);

		//set texture parameters in currently bound texture, controls texture wrapping (or GL_CLAMP?)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

		//linearly interpolate between pixels, MIN if texture is too small for drawing area, MAG if drawing area is smaller than texture
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

		//texture type, level, format to store as, width, height, border, format loaded in
		glTexImage2D(GL_TEXTURE_2D, 0, input_format, width, height, 0, output_format, GL_UNSIGNED_BYTE, pixels);

		//UNBIND
		glBindTexture(GL_TEXTURE_2D, 0);

	} //this

	~this() nothrow @nogc {

		glDeleteTextures(1, &texture);

	} //~this

	//since OpenGL lets you bind multiple textures at once, maximum(32?)
	void bind(int unit) nothrow @nogc {

		assert(unit >= 0 && unit <= 31);
		glActiveTexture(GL_TEXTURE0 + unit); //since this is sequential, this works
		glBindTexture(GL_TEXTURE_2D, texture);

	} //bind

	void unbind() nothrow @nogc {

		glBindTexture(GL_TEXTURE_2D, 0);

	} //unbind

	mixin OpenGLError;

} //Texture

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

	Vec3f pos;
	Vec2f tex_coord;

	this(in Vec3f pos, in Vec2f tex_coord) nothrow @nogc pure {
		this.pos = pos;
		this.tex_coord = tex_coord;
	}

} //Vertex

struct VertexSpec(string imprt, T...) {

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

unittest {

	import smidig.math : Vec2f, Vec3f;

	auto test_vertex = VertexSpec!("gfm.math : Vector", Vec2f, "pos", Vec3f, "normal")();

}

struct Shader {

	//the shader program
	GLuint program;

	//attrib locations
	GLuint[4] bound_attribs;

	//bound uniforms
	GLuint[4] bound_uniforms;

	//alias this for implicit conversions
	alias program this;

	@disable this();
	@disable this(this);

	@property GLuint handle() {
		return program;
	} //handle

	this(in char[] file_name, in AttribLocation[] attribs, in char[16][] uniforms) {

		import smidig.util : cformat;

		assert(uniforms.length <= bound_uniforms.length);

		char[256] fn_buff;

		StringBuffer vs = loadShader(cformat(fn_buff, "%s.vs", file_name.ptr));
		StringBuffer fs = loadShader(cformat(fn_buff, "%s.fs", file_name.ptr));

		auto c_vs = vs.c_str();
		auto c_fs = fs.c_str();

		GLuint vshader = compileShader(&c_vs, GL_VERTEX_SHADER, file_name);
		GLuint fshader = compileShader(&c_fs, GL_FRAGMENT_SHADER, file_name);

		GLuint[2] shaders = [vshader, fshader];
		program = createShaderProgram(shaders, attribs);

		foreach (i, uniform; uniforms) {
			bound_uniforms[i] = glGetUniformLocation(program, uniform.ptr);
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

	void bind() nothrow @nogc {

		glUseProgram(program);

	} //bind

	void unbind() nothrow @nogc {

		glUseProgram(0);

	} //unbind

	mixin OpenGLError;

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

		GLchar[1024] log = void;
		(is_program) ? glGetProgramInfoLog(shader, log.sizeof, null, log.ptr)
			: glGetShaderInfoLog(shader, log.sizeof, null, log.ptr);

		printf("[OpenGL] Error in %s: %s\n", shader_path.ptr, log.ptr);
		return false;

	}

	return true;

} //checkShaderError

GLuint compileShader(const(GLchar*)* shader_source, GLenum shader_type, in char[] shader_path) nothrow {

	GLuint new_shader;
	
	new_shader = glCreateShader(shader_type);
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

/* OpenGL color related functions, darkening and stuff. */
GLfloat[4] to(T : GLfloat[4])(int color, ubyte alpha = 255) nothrow @nogc pure {

	GLfloat[4] gl_color = [ //mask out r, g, b components from int
		cast(float)cast(ubyte)(color>>16)/255,
		cast(float)cast(ubyte)(color>>8)/255,
		cast(float)cast(ubyte)(color)/255,
		cast(float)cast(ubyte)(alpha)/255
	];

	return gl_color;

} //to!GLfloat[4]

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
		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(w, 0, 0.0), Vec2f(1, 0)), // top right
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)), // bottom right

		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(0, h, 0.0), Vec2f(0, 1)), // bottom left
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)) // bottom right
	];

	return vertices;

} //createRectangleVec3f2f
