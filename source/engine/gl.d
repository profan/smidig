module blindfire.gl;

import core.vararg;
import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;

import derelict.opengl3.gl3;
import std.file : read;

struct VAO {

	GLuint vao;

} //VAO

struct VBO {

	GLuint vbo;

} //VBO

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
