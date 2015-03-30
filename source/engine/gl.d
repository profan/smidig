module blindfire.gl;

import core.vararg;
import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;

import derelict.opengl3.gl3;
import blindfire.sys : Vec3f;
import std.file : read;

struct VAO {

	GLuint vao;

} //VAO

struct VBO {

	GLuint vbo;

} //VBO

struct Mesh {

	enum {
		POSITION_VB,
		NUM_BUFFERS
	}

	GLuint vao; //vertex array object
	GLuint[NUM_BUFFERS] vbo; //vertex array buffers
	uint draw_count;

	this(Vec3f* vertices, uint vertices_count) {

		this.draw_count = vertices_count;

		glGenVertexArrays(1, &vao);
		glBindVertexArray(vao);
	
		glGenBuffers(NUM_BUFFERS, vbo.ptr);
		glBindBuffer(GL_ARRAY_BUFFER, vbo[POSITION_VB]); //tells OpenGL to interpret this as an array 
		//upload to GPU, send size in bytes and pointer to array, also tell GPU it will never be modified
		glBufferData(GL_ARRAY_BUFFER, vertices_count * vertices[0].sizeof, vertices, GL_STATIC_DRAW);

		glEnableVertexAttribArray(0);
		
		//0 corresponds to precious attribarray, 3 is number of elements in vertex, set type to float (don't normalize(GL_FALSE))
		// 0 - skip nothing to find the next attribute, 0 - distance from beginning to find the first attribute
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 0, cast(const(void)*)null);
		
		glBindVertexArray(0); //unbind previous vao

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

struct Vertex {

} //Vertex

struct Shader {

	//the shader program
	GLuint program;

	//alias this for implicit conversions
	alias program this;

	this (in char[] file_name) {

		char* vs = load_shader(file_name ~ ".vs");	
		char* fs = load_shader(file_name ~ ".fs");	
		GLuint vshader = compile_shader(&vs, GL_VERTEX_SHADER);
		GLuint fshader = compile_shader(&fs, GL_FRAGMENT_SHADER);

		program = create_shader_program(vshader, fshader);

		glDetachShader(program, vshader);
		glDetachShader(program, fshader);
		glDeleteShader(vshader);
		glDeleteShader(fshader);

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

GLuint create_shader_program(GLuint[] shaders...) {

	GLuint program = glCreateProgram();

	foreach(shader; shaders) {
		glAttachShader(program, shader);
	}

	glBindAttribLocation(program, 0, "position");

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
