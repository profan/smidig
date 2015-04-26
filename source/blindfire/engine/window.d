module blindfire.engine.window;

import std.utf : toUTFz;
import std.stdio : writefln;
import core.stdc.stdio;
import std.conv;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;

import gfm.math : Matrix;
alias Mat4f = Matrix!(float, 4, 4);

struct Window {

	private {
		bool alive;
		char* c_title; //keep this here so the char* for toStringz doesn't point to nowhere!
		SDL_Window* window;
		SDL_GLContext glcontext;
	}

	//gl related data
	Mat4f view_projection;

	//window data
	private uint window_width, window_height;

	this(in char[] title, uint width, uint height) {

		uint flags = 0;
		flags |= SDL_WINDOW_OPENGL;
		flags |= SDL_WINDOW_RESIZABLE;

		this.c_title = toUTFz!(char*)(title);
		this.window = SDL_CreateWindow(
			c_title,
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			width, height,
			flags);
		
		window_width = width;
		window_height = height;
		assert(window != null);

		//GLint major = 4, minor = 0;
		//SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, major);
		//SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, minor);
		glcontext = SDL_GL_CreateContext(window);

		if (glcontext == null) {
			GLenum glErr = glGetError();
			printf("[OpenGL] Error: %s", glErr);
		}

		const GLchar* sGLVersion_ren = glGetString(GL_RENDERER);
		const GLchar* sGLVersion_main = glGetString(GL_VERSION);
		const GLchar* sGLVersion_shader = glGetString(GL_SHADING_LANGUAGE_VERSION);
		printf("[OpenGL] renderer is: %s \n", sGLVersion_ren);
		printf("[OpenGL] version is: %s \n", sGLVersion_main);
		printf("[OpenGL] GLSL version is: %s \n", sGLVersion_shader);
		printf("[OpenGL] Loading GL Extensions. \n");
		DerelictGL3.reload();
		alive = true;

		view_projection = Mat4f.orthographic(0.0f, width, height, 0.0f, 0.0f, 1.0f);

	}

	~this() {

		SDL_GL_DeleteContext(glcontext);
		SDL_DestroyWindow(window);

	}

	@property const(char*) title() const { return c_title; }
	@property void title(in char[] new_title) {
		c_title = toUTFz!(char*)(new_title);
		SDL_SetWindowTitle(window, c_title);
	}

	@property uint width() const { return window_width; }
	@property uint height() const { return window_height; }

	@property bool is_alive() const { return alive; }
	@property void is_alive(bool status) { alive = status; }

	void render_clear(int color) {

		import blindfire.engine.gl : int_to_glcolor;

		auto col = int_to_glcolor(color, 255);
		glClearColor(col[0], col[1], col[2], col[3]);
		glClear(GL_COLOR_BUFFER_BIT);

	}

	void render_present() {
		SDL_GL_SwapWindow(window);
	}

	void toggle_wireframe() {
		
		static GLenum current = GL_FILL;

		current = (current == GL_FILL) ? GL_LINE : GL_FILL;
		glPolygonMode(GL_FRONT_AND_BACK, current);

	}

	void handle_events(ref SDL_Event ev) {
		if (ev.type == SDL_QUIT) {
			alive = false;
		} else if (ev.type == SDL_WINDOWEVENT) {
			switch (ev.window.event) {
				case SDL_WINDOWEVENT_SIZE_CHANGED:
					window_width = ev.window.data1;
					window_height = ev.window.data2;
					glViewport(0, 0, window_width, window_height);
					view_projection = Mat4f.orthographic(0.0f, window_width, window_height, 0.0f, 0.0f, 1.0f);
					break;
				case SDL_WINDOWEVENT_EXPOSED:
					break;
				case SDL_WINDOWEVENT_ENTER:
					//mouse inside window
					break;
				case SDL_WINDOWEVENT_LEAVE:
					//mouse outside window
					break;
				case SDL_WINDOWEVENT_FOCUS_GAINED:
					//set some stuff
					break;
				case SDL_WINDOWEVENT_FOCUS_LOST:
					//unset some stuff
					break;
				default:
					break;
			}
		}
	}

} //Window