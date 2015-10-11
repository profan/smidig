module blindfire.engine.gl;

import core.stdc.stdio : printf;
import core.stdc.stdlib : malloc, free;
import std.string : toStringz;
import std.stdio : writefln;
import std.file : read;

import derelict.opengl3.gl3;

import blindfire.engine.defs : Vec2i, Vec2f, Vec3f, Mat3f, Mat4f;

mixin template OpenGLError() {

	invariant {

		GLenum status = glGetError();
		if (status != GL_NO_ERROR) {
			writefln("[OpenGL : %s] Error: %d", typeof(this).stringof, status);
		}

	}

} //OpenGLError

struct VAO {

	GLuint vao;

} //VAO

struct VBO {

	GLuint vbo;

} //VBO

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
		Vertex[6] vertices = create_rectangle_vec3f2f(w, h);
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
		Vertex[6] vertices = create_rectangle_vec3f2f(w, h);
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

	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.collections : Array;

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

	import blindfire.engine.defs : Vec2f;
	import blindfire.engine.memory : theAllocator;

	auto origin = Vec2f(0, 0);
	auto orientation = Vec2f(0, 1);

	auto part_sys = ParticleSystem!Vec2f(theAllocator, null, null, null, origin, orientation, 32);

}

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
		SDL_Surface* image = IMG_Load(toStringz(file_name));
		scope(exit) SDL_FreeSurface(image);

		if (image == null) {
			printf("[OpenGL] Failed to load texture %s : %s", toStringz(file_name), IMG_GetError());
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

struct VertexSpec(T...) {

} //VertexSpec

struct Shader {

	//the shader program
	GLuint program;

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

		assert(uniforms.length <= bound_uniforms.length);

		const char* vs = load_shader(file_name ~ ".vs");
		const char* fs = load_shader(file_name ~ ".fs");
		GLuint vshader = compile_shader(&vs, GL_VERTEX_SHADER, file_name);
		GLuint fshader = compile_shader(&fs, GL_FRAGMENT_SHADER, file_name);

		GLuint[2] shaders = [vshader, fshader];
		program = create_shader_program(shaders, attribs);

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

import blindfire.engine.util : load_file;

const(char*) load_shader(in char[] file_name) {
	import std.file : read;
	return toStringz(cast(immutable char[])read(file_name));
} //load_shader

bool check_shader_error(GLuint shader, GLuint flag, bool isProgram, in char[] shader_path) nothrow {

	GLint result;

	if (isProgram) {
		glGetProgramiv(shader, flag, &result);
	} else {
		glGetShaderiv(shader, flag, &result);
	}

	if (result == GL_FALSE) {

		GLchar[1024] log = void;
		if (isProgram) {
			glGetProgramInfoLog(shader, log.sizeof, null, log.ptr);
		} else {
			glGetShaderInfoLog(shader, log.sizeof, null, log.ptr);
		}

		printf("[OpenGL] Error in %s: %s\n", toStringz(shader_path), log.ptr);
		return false;

	}

	return true;

} //check_shader_error

GLuint compile_shader(const(GLchar*)* shader_source, GLenum shader_type, in char[] shader_path) nothrow {

	GLuint new_shader;
	
	new_shader = glCreateShader(shader_type);
	glShaderSource(new_shader, 1, shader_source, null);
	glCompileShader(new_shader);

	if (!check_shader_error(new_shader, GL_COMPILE_STATUS, false, shader_path)) {
		glDeleteShader(new_shader);
		return 0;
	}

	return new_shader;

} //compile_shader

GLuint create_shader_program(in GLuint[] shaders, in AttribLocation[] attribs) nothrow {

	GLuint program = glCreateProgram();

	foreach(shader; shaders) {
		glAttachShader(program, shader);
	}

	foreach (ref attr; attribs) {
		glBindAttribLocation(program, attr.offset, attr.identifier.ptr);
	}

	glLinkProgram(program);
	if (!check_shader_error(program, GL_LINK_STATUS, true, "")) {
		glDeleteShader(program);
		return 0;
	}

	glValidateProgram(program);
	if (!check_shader_error(program, GL_VALIDATE_STATUS, true, "")) {
		glDeleteShader(program);
		return 0;
	}

	return program;

} //create_shader_program

/* OpenGL color related functions, darkening and stuff. */
GLfloat[4] int_to_glcolor(int color, ubyte alpha = 255) nothrow @nogc pure {

	GLfloat[4] gl_color = [ //mask out r, g, b components from int
		cast(float)cast(ubyte)(color>>16)/255,
		cast(float)cast(ubyte)(color>>8)/255,
		cast(float)cast(ubyte)(color)/255,
		cast(float)cast(ubyte)(alpha)/255
	];

	return gl_color;

} //int_to_gl_color

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

auto create_rectangle_vec3f(float w, float h) nothrow @nogc pure {

	Vec3f[6] vertices = [
		Vec3f(0.0f, 0.0f, 0.0f), // top left
		Vec3f(w, 0.0f, 0.0f), // top right
		Vec3f(w, h, 0.0f), // bottom right

		Vec3f(0.0f, 0.0f, 0.0f), // top left
		Vec3f(0.0f, h, 0.0f), // bottom left
		Vec3f(w, h, 0.0f) // bottom right
	];

	return vertices;

} //create_rectangle_vec3f

auto create_rectangle_vec3f2f(float w, float h) nothrow @nogc pure {

	Vertex[6] vertices = [
		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(w, 0, 0.0), Vec2f(1, 0)), // top right
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)), // bottom right

		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(0, h, 0.0), Vec2f(0, 1)), // bottom left
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)) // bottom right
	];

	return vertices;

} //create_rectangle_vec3f2f
