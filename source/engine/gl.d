module blindfire.gl;

import core.vararg;
import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import std.stdio : writefln;
import std.file : read;

import derelict.opengl3.gl3;

import gfm.math;
import blindfire.defs;

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

}

struct Text {

	import derelict.sdl2.sdl;
	import derelict.sdl2.ttf;

	enum MAX_SIZE = 64;
	char[MAX_SIZE] content;

	Mesh mesh;
	Texture texture;
	Shader* shader;

	@property int width() { return texture.width; }
	@property int height() { return texture.height; }

	@property ref char[MAX_SIZE] text() { return content; }
	@property void text(ref char[MAX_SIZE] new_text) { content = new_text[]; }

	this(TTF_Font* font, char[64] initial_text, int font_color, Shader* text_shader)  {

		content = initial_text;
		SDL_Color color = {cast(ubyte)(font_color>>16), cast(ubyte)(font_color>>8), cast(ubyte)(font_color)};
		SDL_Surface* surf = TTF_RenderUTF8_Blended(font, initial_text.ptr, color);
		scope(exit) SDL_FreeSurface(surf);

		texture = Texture(surf.pixels, surf.w, surf.h, GL_RGBA, GL_RGBA);

		int w = texture.width;
		int h = texture.height;
		//cartesian coordinate system, inverted y component to not draw upside down.
		Vertex[6] vertices = [
			Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
			Vertex(Vec3f(w, 0, 0.0), Vec2f(1, 0)), // top right
			Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)), // bottom right

			Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
			Vertex(Vec3f(0, h, 0.0), Vec2f(0, 1)), // bottom left
			Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)) // bottom right
		];

		mesh = Mesh(vertices.ptr, vertices.length);
		shader = text_shader;
	
	}

	void draw(ref Mat4f projection, Vec2f position) {

		auto tf = Transform(position, Vec2f(0.0f, 0.0f), Vec2f(1.0f, 1.0f));

		shader.bind();
		texture.bind(0);
		shader.update(projection, tf);
		mesh.draw();
		texture.unbind();
		shader.unbind();

	}

	~this() {

	}

} //Text

struct Mesh {

	enum {
		POSITION_VB,
		NUM_BUFFERS
	}

	GLuint vao; //vertex array object
	GLuint[NUM_BUFFERS] vbo; //vertex array buffers
	uint draw_count;

	this(Vertex* vertices, uint vertices_count) {

		this.draw_count = vertices_count;

		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);

		//create NUM_BUFFERS
		glGenBuffers(NUM_BUFFERS, vbo.ptr);

		//vertex position buffer
		glBindBuffer(GL_ARRAY_BUFFER, vbo[POSITION_VB]); //tells OpenGL to interpret this as an array 
		glBufferData(GL_ARRAY_BUFFER, vertices_count * vertices[0].sizeof, vertices, GL_STATIC_DRAW);
		//upload to GPU, send size in bytes and pointer to array, also tell GPU it will never be modified

		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vertices[0].sizeof, cast(const(void)*)null);
		//0 corresponds to precious attribarray, 3 is number of elements in vertex, set type to float (don't normalize(GL_FALSE))
		// 0 - skip nothing to find the next attribute, 0 - distance from beginning to find the first attribute
		// use sizeof of tex_coord as stride

		glEnableVertexAttribArray(1);
		glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, vertices[0].sizeof, cast(const(void)*)vertices[0].pos.sizeof);

		//UNBIND
		glBindVertexArray(0); //unbind

	}

	@disable this(this);

	~this() {

		glDeleteVertexArrays(1, &vao);

	}

	void draw() {

		glBindVertexArray(vao); //set vertex array to use

		glDrawArrays(GL_TRIANGLES, 0, draw_count); //read from beginning (offset is 0), draw draw_count vertices

		glBindVertexArray(0); //unbind

	}

} //Mesh

//use SDL2 for loading textures, since we're already using it for windowing.
struct Texture {

	import derelict.sdl2.sdl;
	import derelict.sdl2.image;

	import std.string : toStringz;

	GLuint texture; //OpenGL handle for texture
	int width, height;

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

	}

	this(void* pixels, int width, int height, GLenum input_format, GLenum output_format) {

		this.width = width;
		this.height = height;
	
		//generate single texture, put handle in texture
		glGenTextures(1, &texture);

		//normal 2d texture, bind to our texture handle
		glBindTexture(GL_TEXTURE_2D, texture);

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

		GLenum status = glGetError();
		if (status != GL_NO_ERROR) {
			writefln("[OpenGL] Texture loading error: %d", status);
		}

	}

	@disable this(this);

	~this() {

		glDeleteTextures(1, &texture);

	}

	//since OpenGL lets you bind multiple textures at once, maximum(32?)
	void bind(int unit) {

		assert(unit >= 0 && unit <= 31);
		glActiveTexture(GL_TEXTURE0 + unit); //since this is sequential, this works
		glBindTexture(GL_TEXTURE_2D, texture);

	}

	void unbind() {

		glBindTexture(GL_TEXTURE_2D, 0);

	}

} //Texture

struct Transform {

	Vec2f position;
	Vec2f rotation;
	Vec2f scale;

	this(in Vec2f pos, in Vec2f rotation = Vec2f(0.0f, 0.0f), in Vec2f scale = Vec2f(1.0f, 1.0f)) {
		this.position = pos;
		this.rotation = rotation;
		this.scale = scale;
	}

	@property Mat4f transform() const {

		Mat4f posMatrix = Mat4f.translation(Vec3f(position, 0.0f));
		Mat4f rotXMatrix = Mat4f.rotation(rotation.x, Vec3f(1, 0, 0));
		Mat4f rotYMatrix = Mat4f.rotation(rotation.y, Vec3f(0, 1, 0));
		Mat4f rotZMatrix = Mat4f.rotation(0.0f, Vec3f(0, 0, 1));
		Mat4f scaleMatrix = Mat4f.scaling(Vec3f(scale, 1.0f));
		
		Mat4f rotMatrix = rotXMatrix * rotYMatrix * rotZMatrix;

		return posMatrix * rotMatrix * scaleMatrix;

	}

} //Transform

struct Vertex {

	this(in Vec3f pos, in Vec2f tex_coord) {
		this.pos = pos;
		this.tex_coord = tex_coord;
	}

	Vec3f pos;
	Vec2f tex_coord;

} //Vertex

struct Shader {

	//the shader program
	GLuint program;

	//bound uniforms
	GLuint[4] bound_uniforms;

	//alias this for implicit conversions
	alias program this;

	this (in char[] file_name, in AttribLocation[] attribs, in char[16][] uniforms) {

		char* vs = load_shader(file_name ~ ".vs");	
		char* fs = load_shader(file_name ~ ".fs");	
		GLuint vshader = compile_shader(&vs, GL_VERTEX_SHADER);
		GLuint fshader = compile_shader(&fs, GL_FRAGMENT_SHADER);

		GLuint[2] shaders = [vshader, fshader];
		program = create_shader_program(shaders, attribs);

		foreach (i, uniform; uniforms) {
			bound_uniforms[i] = glGetUniformLocation(program, uniform.ptr);
		}

		glDetachShader(program, vshader);
		glDetachShader(program, fshader);
		glDeleteShader(vshader);
		glDeleteShader(fshader);

	}

	void update(ref Mat4f projection, ref Transform transform) {

		Mat4f model = transform.transform;

		//transpose matrix, since row major, not column
		glUniformMatrix4fv(bound_uniforms[0], 1, GL_TRUE, model.ptr);
		glUniformMatrix4fv(bound_uniforms[1], 1, GL_TRUE, projection.ptr);

	}

	void update(ref Mat4f projection, ref Mat4f transform) {

		//transpose matrix, since row major, not column
		glUniformMatrix4fv(bound_uniforms[0], 1, GL_TRUE, transform.ptr);
		glUniformMatrix4fv(bound_uniforms[1], 1, GL_TRUE, projection.ptr);

	}

	~this() {

		glDeleteProgram(program);

	}


	void bind() {

		glUseProgram(program);

	}

	void unbind() {

		glUseProgram(0);

	}

} //Shader

//C-ish code ahoy

char* load_shader(in char[] file_name) {
	return cast(char*)read(file_name);
}

bool check_shader_error(GLuint shader, GLuint flag, bool isProgram) {

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

		printf("[OpenGL] Error: %s\n", log.ptr);
		return false;

	}

	return true;

}

GLuint compile_shader(const(GLchar*)* shader_source, GLenum shader_type) {

	GLuint new_shader;
	
	new_shader = glCreateShader(shader_type);
	glShaderSource(new_shader, 1, shader_source, null);
	glCompileShader(new_shader);

	if (!check_shader_error(new_shader, GL_COMPILE_STATUS, false)) {
		glDeleteShader(new_shader);
		return 0;
	}

	return new_shader;

}

GLuint create_shader_program(in GLuint[] shaders, in AttribLocation[] attribs) {

	GLuint program = glCreateProgram();

	foreach(shader; shaders) {
		glAttachShader(program, shader);
	}

	foreach (ref attr; attribs) {
		glBindAttribLocation(program, attr.offset, attr.identifier.ptr);
	}

	glLinkProgram(program);
	if (!check_shader_error(program, GL_LINK_STATUS, true)) {
		glDeleteShader(program);
		return 0;
	}

	glValidateProgram(program);
	if (!check_shader_error(program, GL_VALIDATE_STATUS, true)) {
		glDeleteShader(program);
		return 0;
	}

	return program;

}
