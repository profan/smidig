module smidig.window;

import core.stdc.stdio;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;

import gfm.math : Matrix;
alias Mat4f = Matrix!(float, 4, 4);

/**
 * Structure to represent the window, at present uses SDL2 and OpenGL directly.
*/
struct Window {

	static const char* framebuffer_vs = "
		#version 330 core

		in vec3 position;
		in vec2 tex_coord;

		out vec2 tex_coord0;

		uniform mat4 transform;
		uniform mat4 perspective;

		void main() {
			gl_Position = perspective * transform * vec4(position, 1.0);
			tex_coord0 = tex_coord;
		}
	";

	static const char* framebuffer_fs = "
		#version 330 core

		in vec2 tex_coord0;

		uniform sampler2D diffuse;

		void main() {
			gl_FragColor = texture2D(diffuse, tex_coord0);
		}
	";


	import smidig.gl : AttribLocation, RenderTarget, Shader;
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
		Mat4f view_projection_; //TODO ARH

	}

	// holds texture buffer for screen, etc

	Shader render_shader_;
	RenderTarget render_target_;
	alias render_target_ this;

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
		SDL_GetWindowSize(window_, &window_width_, &window_height_); //sets window width and height

		int creation_result = -1;
		while (creation_result != 0) {
			//later, progressively try creating contexts of lower versions until a supported one is found
			creation_result = createGLContext(gl_major, gl_minor);
		}

		AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
		char[16][2] uniforms = ["transform", "perspective"];
		render_shader_ = Shader(&framebuffer_vs, &framebuffer_fs, "framebuffer", attributes[], uniforms[]);
		render_target_ = RenderTarget(&render_shader_, window_width_, window_height_);
		view_projection_ = Mat4f.orthographic(0.0f, window_width_, window_height_, 0.0f, 0.0f, 1.0f);
		alive_ = true;

	} //this

	~this() {

		SDL_GL_DeleteContext(glcontext_);
		SDL_DestroyWindow(window_);

	} //~this

	int createGLContext(int gl_major, int gl_minor) {

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

			return glErr;

		}

		const GLchar* sGLVersion_ren = glGetString(GL_RENDERER);
		const GLchar* sGLVersion_main = glGetString(GL_VERSION);
		const GLchar* sGLVersion_shader = glGetString(GL_SHADING_LANGUAGE_VERSION);
		printf("[OpenGL] renderer is: %s \n", sGLVersion_ren);
		printf("[OpenGL] version is: %s \n", sGLVersion_main);
		printf("[OpenGL] GLSL version is: %s \n", sGLVersion_shader);
		printf("[OpenGL] Loading GL Extensions. \n");
		DerelictGL3.reload();

		return 0; //all is well

	} //createGLContext

	void renderClear(int color) {

		import smidig.gl : GLColor;
		import smidig.conv : to;

		auto col = to!GLColor(color, 255);
		glClearColor(col[0], col[1], col[2], col[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, width, height);

		render_target_.bind_fbo();

	} //renderClear

	void renderPresent() {

		render_target_.unbind_fbo();
		render_target_.draw(view_projection_);
		SDL_GL_SwapWindow(window_);

	} //renderPresent

	void setViewport(int w, int h) {

		window_width_ = w;
		window_height_ = h;
		render_target_.resize(window_width_, window_height_);
		view_projection_ = Mat4f.orthographic(0.0f, window_width_, window_height_, 0.0f, 0.0f, 1.0f);
		glViewport(0, 0, width, height);

	} //setViewport

	void toggleFullscreen() {

		SDL_SetWindowFullscreen(window_, (fullscreen_) ? 0 : SDL_WINDOW_FULLSCREEN);
		fullscreen_ = !fullscreen_;

	} //toggleFullscreen

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
					setViewport(ev.window.data1, ev.window.data2);
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

				//mouse inside window
				case SDL_WINDOWEVENT_ENTER:
					break;

				//mouse outside window
				case SDL_WINDOWEVENT_LEAVE:
					break;

				//got keyboard focus
				case SDL_WINDOWEVENT_FOCUS_GAINED:
					break;

				//lost keyboard focus
				case SDL_WINDOWEVENT_FOCUS_LOST:
					break;

				default:
					break;
					//assert(false, "unhandled event!");

			}
		}

	} //handleEvents

} //Window
