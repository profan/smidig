module smidig.window;

import core.stdc.stdio;

import derelict.sdl2.sdl;
import derelict.sdl2.image;
import derelict.sdl2.ttf;

import derelict.freetype.ft;
import derelict.opengl3.gl3;
import derelict.opengl3.gl;

import gfm.math : Matrix;
alias Mat4f = Matrix!(float, 4, 4);

/**
 * Structure to represent the window, at present uses SDL2 and OpenGL directly.
*/
struct Window {

	static immutable char* framebuffer_vs = "
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

	static immutable char* framebuffer_fs = "
		#version 330 core

		in vec2 tex_coord0;

		uniform sampler2D diffuse;

		void main() {
			gl_FragColor = texture2D(diffuse, tex_coord0);
		}
	";


	import smidig.gl : AttribLocation, RenderTarget, Shader;
	import smidig.collections : String;

	enum Error {
		RendererCreationFailed = "Failed to create window!",
		ContextCreationFailed = "Failed to create OpenGL context of at least version 3.3!",
		Success = "Window Creation Succeeded!"
	} //Error

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

		// holds texture buffer for screen, etc
		static Shader render_shader_ = void;
		RenderTarget render_target_ = void;

	}

	alias render_target this;

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

		ref RenderTarget render_target() nothrow @nogc { return render_target_; }

	}

	@disable this(this);

	~this() {

		import std.stdio : writefln;

		if (window_) {
			debug writefln("Destroying Window");
			SDL_GL_DeleteContext(glcontext_);
			SDL_DestroyWindow(window_);
		}

	} //~this

	static Error create(ref Window window, in char[] title = "Default Window", uint width = 640, uint height = 480) {

		import smidig.memory : construct; //FIXME abolish this part, more error handling

		initialize(); //load libs if not already loaded

		window.title_ = String(title); //TODO also error handling? not sure if should have, prob not

		uint flags = 0;
		flags |= SDL_WINDOW_OPENGL;
		flags |= SDL_WINDOW_RESIZABLE;

		window.window_ = SDL_CreateWindow(
			window.title_.c_str,
			SDL_WINDOWPOS_UNDEFINED,
			SDL_WINDOWPOS_UNDEFINED,
			width, height,
			flags);

		// check if valid
		if (!window.window_) { return Error.RendererCreationFailed; }

		// get window height and set vars in struct
		SDL_GetWindowSize(window.window_, &window.window_width_, &window.window_height_);

		// try creating context, TODO is setting a "min" version
		int result = window.createGLContext(3, 3);
		if (result == -1) { return Error.ContextCreationFailed; }

		// set up render target, view projection shit
		with (window) {

			// FIXME setup shader and render target with factory constructors, so errors can be checked
			AttribLocation[2] attributes = [AttribLocation(0, "position"), AttribLocation(1, "tex_coord")];
			char[16][2] uniforms = ["transform", "perspective"];
			render_shader_.construct(&framebuffer_vs, &framebuffer_fs, "framebuffer", attributes[], uniforms[]);
			render_target_.construct(&render_shader_, window_width_, window_height_);
			view_projection_ = Mat4f.orthographic(0.0f, window_width_, window_height_, 0.0f, 0.0f, 1.0f);
			alive_ = true;

		}

		return Error.Success;

	} //create

	static void initialize() {

		import std.meta : AliasSeq;
		import derelict.util.exception;

		shared static bool is_initialized;
		if (is_initialized) return;

		ShouldThrow missingSymFunc(string symName) {

			alias symbols = AliasSeq!(
				"FT_Gzip_Uncompress",
				"SDL_QueueAudio",
				"SDL_GetQueuedAudioSize",
				"SDL_ClearQueuedAudio",
				"SDL_HasAVX2",
				"SDL_GetGlobalMouseState",
				"SDL_WarpMouseGlobal",
				"SDL_CaptureMouse",
				"SDL_RenderIsClipEnabled",
				"SDL_SetWindowHitTest"
			);

			foreach (sym; symbols) {
				if (symName == sym) return ShouldThrow.No;
			}

			return ShouldThrow.Yes;

		} //missingSymFunc

		import gcarena;

		alias libs = AliasSeq!(
			DerelictSDL2, DerelictSDL2Image,
			DerelictSDL2ttf, DerelictFT,
			DerelictGL
		);

		auto ar = useCleanArena();

		foreach (T; libs) {
			T.missingSymbolCallback = &missingSymFunc;
			T.load();
		}

		if (SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER) < 0) {
			printf("[Engine] SDL_Init, could not initialize: %s", SDL_GetError());
			assert(0);
		}

		if (TTF_Init() == -1) {
			printf("[Engine] TTF_Init: %s\n", TTF_GetError());
			assert(0);
		}

		is_initialized = true;

	} //initialize

	extern(C) nothrow @nogc
	static void openGLCallbackFunction(
		GLenum source, GLenum type,
		GLuint id, GLenum severity,
		GLsizei length, const (GLchar)* message,
		void* userParam)
	{

		import smidig.conv : to;

		printf("Message: %s \nSource: %s \nType: %s \nID: %d \nSeverity: %s\n\n",
			message, to!(char*)(source), to!(char*)(type), id, to!(char*)(severity));

		if (severity == GL_DEBUG_SEVERITY_HIGH) {
			printf("Aborting...\n");
		}

	} //openGLCallbackFunction

	int createGLContext(int gl_major, int gl_minor) {

		// OpenGL related attributes
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, gl_major);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, gl_minor);
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
		SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
		SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 32);

		// debuggering!
		SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, SDL_GL_CONTEXT_DEBUG_FLAG);

		glcontext_ = SDL_GL_CreateContext(window_);

		if (!glcontext_) {

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

		import trackallocs;
		import smidig.util : withGCArena;
		auto gl_version = withGCArena(
			() => DerelictGL3.reload(),
			() => startTrackingAllocs()
		);

		// enable debuggering
		glEnable(GL_DEBUG_OUTPUT);
		glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
		glDebugMessageCallback(&openGLCallbackFunction, null);

		//enable all
		glDebugMessageControl(
			GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, null, true
		);

		//disable notification messages
		glDebugMessageControl(
			GL_DONT_CARE, GL_DONT_CARE, GL_DEBUG_SEVERITY_NOTIFICATION, 0, null, false
		);

		return 0; //all is well

	} //createGLContext

	void renderClear(int color) {

		import smidig.gl : GLColor;
		import smidig.conv : to;

		auto col = to!GLColor(color, 255);
		glClearColor(col[0], col[1], col[2], col[3]);
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		glViewport(0, 0, width, height);

		render_target_.bind_fbo(color);

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

	mixin WindowModule;

} //Window

mixin template WindowModule() {

	enum name = "WindowModule";
	enum identifier = "window_";

	static bool onInit(E)(ref E engine) {

		auto result = Window.create(engine.window_);

		final switch (result) with (Window.Error) {
			case RendererCreationFailed, ContextCreationFailed:
				return false;
			case Success:
				break;
		}

		return true;

	} //onInit

	static void linkDependencies(E)(ref E engine) {

		engine.input_handler_.addListener(&engine.window_.handleEvents, SDL_WINDOWEVENT, SDL_QUIT);

	} //linkDependencies

} //WindowModule
