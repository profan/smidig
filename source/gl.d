module sundownstandoff.gl;

import core.vararg;
import std.c.stdlib;
import core.stdc.stdio;
import derelict.opengl3.gl3;

//C-ish code ahoy
bool check_shader_compile_success(GLuint shader) {

	GLint length, result;

	glGetShaderiv(shader, GL_COMPILE_STATUS, &result);
	if (result == GL_FALSE) {
		char* log;
		glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &length);
		log = cast(char*)malloc(length);
		glGetShaderInfoLog(shader, length, &result, log);
		printf("OpenGL Error: Unable to compile shader: %s", log);
		free(log);
		return false;
	}

	return true;

}

GLuint compile_shader(const(GLchar*)* shader_source, GLenum shader_type) {

	GLuint new_shader;
	
	new_shader = glCreateShader(shader_type);
	glShaderSource(new_shader, 1, shader_source, null);
	glCompileShader(new_shader);

	if (!check_shader_compile_success(new_shader)) {
		glDeleteShader(new_shader);
		return 0;
	}

	return new_shader;

}

GLuint create_shader_program(GLuint shaders[]...) {

	GLuint program = glCreateProgram();

	foreach(shader; shaders) {
		glAttachShader(program, shader);
	}

	glBindFragDataLocation(program, 0, "outColor");
	glLinkProgram(program);

	return program;

}
