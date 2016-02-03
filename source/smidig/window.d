module smidig.window;

import core.stdc.stdio;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;

import gfm.math : Matrix;
alias Mat4f = Matrix!(float, 4, 4);

struct Window {

	import smidig.collections : String;

	private {

		SDL_Window* window_;
		SDL_GLContext glcontext_;

		//info
		String title_;
		bool fullscreen_;
		bool alive_;

		//gl specific
		GLenum polygon_mode_;

		//window data
		int window_width_, window_height_;

	}

	//gl related data
	Mat4f view_projection;

	@property {

		const(char*) title() const {
			return title_.c_str;
		} //title

		void title(in char[] new_title) {
			this.title_ = String(new_title);
			SDL_SetWindowTitle(window_, title_.c_str);
		} //title

		uint width() const nothrow @nogc { return window_width_; }
		uint height() const nothrow @nogc { return window_height_; }

		bool is_alive() const nothrow @nogc { return alive_; }
		void is_alive(bool status) nothrow @nogc { alive_ = status; }

	}

	@disable this();
	@disable this(this);

	this(void* external_window) {
		
		SDL_Window* new_window = SDL_CreateWindowFrom(external_window);
		this(new_window);

	} //this

	this(in char[] title, uint width, uint height) {

		this.title_ = String(title);

		uint flags = 0;
		flags |= SDL_WINDOW_OPENGL;
		flags |= SDL_WINDOW_RESIZABLE;

		SDL_Window* new_window = SDL_CreateWindow(
				title_.c_str,
				SDL_WINDOWPOS_UNDEFINED,
				SDL_WINDOWPOS_UNDEFINED,
				width, height,
				flags);

		this(new_window);

	} //this

	this(SDL_Window* in_window, int gl_major = 3, int gl_minor = 3) {

		assert(in_window != null);
		assert(gl_major >= 3 && gl_minor >= 3, "desired OpenGL version needs to be at least 3.3!");

		window_ = in_window;
		SDL_GetWindowSize(window_, &window_width_, &window_height_);
		createGLContext(gl_major, gl_minor); //DO EET

		alive_ = true;

		view_projection = Mat4f.orthographic(0.0f, width, height, 0.0f, 0.0f, 1.0f);

	} //this

	~this() {

		SDL_GL_DeleteContext(glcontext_);
		SDL_DestroyWindow(window_);

	} //~this

	void createGLContext(int gl_major, int gl_minor) {

		// OpenGL related attributes
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, gl_major);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, gl_minor);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 32);

		glcontext_ = SDL_GL_CreateContext(window_);
		if (glcontext_ == null) {
			GLenum glErr = glGetError();
			printf("[OpenGL] Error: %d", glErr);
		}

		const GLchar* sGLVersion_ren = glGetString(GL_RENDERER);
		const GLchar* sGLVersion_main = glGetString(GL_VERSION);
		const GLchar* sGLVersion_shader = glGetString(GL_SHADING_LANGUAGE_VERSION);
		printf("[OpenGL] renderer is: %s \n", sGLVersion_ren);
		printf("[OpenGL] version is: %s \n", sGLVersion_main);
		printf("[OpenGL] GLSL version is: %s \n", sGLVersion_shader);
		printf("[OpenGL] Loading GL Extensions. \n");
		DerelictGL3.reload();

	} //createGLContext

	void renderClear(int color) {

		import smidig.gl : GLColor;
		import smidig.conv : to;

		auto col = to!GLColor(color, 255);
		glClearColor(col[0], col[1], col[2], col[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

	} //renderClear

	void renderPresent() {
		SDL_GL_SwapWindow(window_);
	} //renderPresent

	void toggleFullscreen() {

		SDL_SetWindowFullscreen(window_, (fullscreen_) ? 0 : SDL_WINDOW_FULLSCREEN);
		fullscreen_ = !fullscreen_;

	} //toggle_fullscreen

	void toggleWireframe() {
		
		polygon_mode_ = (polygon_mode_ == GL_FILL) ? GL_LINE : GL_FILL;
		glPolygonMode(GL_FRONT_AND_BACK, polygon_mode_);

	} //toggleWireframe

	void handleEvents(ref SDL_Event ev) {

		if (ev.type == SDL_QUIT) {
			alive_ = false;
		} else if (ev.type == SDL_WINDOWEVENT) {

			switch (ev.window.event) {

				case SDL_WINDOWEVENT_SIZE_CHANGED:
					window_width_ = ev.window.data1;
					window_height_ = ev.window.data2;
					glViewport(0, 0, window_width_, window_height_);
					view_projection = Mat4f.orthographic(0.0f, window_width_, window_height_, 0.0f, 0.0f, 1.0f);
					break;

				case SDL_WINDOWEVENT_RESIZED:
					break;

				case SDL_WINDOWEVENT_RESTORED:
					break;

				case SDL_WINDOWEVENT_MINIMIZED:
					break;

				case SDL_WINDOWEVENT_MAXIMIZED:
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
					//got keyboard focus
					break;

				case SDL_WINDOWEVENT_FOCUS_LOST:
					//lost keyboard focus
					break;

				default:
					break;

			}
		}

	} //handleEvents

} //Window
