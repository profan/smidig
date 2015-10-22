module blindfire.engine.input;

import derelict.sdl2.sdl;
import blindfire.engine.util : makeFlagEnum;

alias void delegate(ref SDL_Event) EventDelegate;
alias void delegate() KeyDelegate;
alias void delegate(int, int) MouseDelegate;
alias void delegate(int) AxisDelegate;

MouseKeyState to(S : MouseKeyState)(KeyState state) {
	return (state == state.UP) ? MouseKeyState.UP : MouseKeyState.DOWN;
} //to

enum MouseKeyState {

	UP = SDL_MOUSEBUTTONUP,
	DOWN = SDL_MOUSEBUTTONDOWN

} //MouseKeyState

enum KeyState {

	UP = SDL_RELEASED,
	DOWN = SDL_PRESSED

} //KeyState

struct KeyBind {

	SDL_Scancode key;
	KeyDelegate func;
	KeyState state;

} //KeyBind

struct MouseBind {

	Uint8 mousebtn;
	MouseDelegate func;
	MouseKeyState state;

} //MouseBind

struct Controller {

	int device_id;
	SDL_GameController* handle;

	bool opEquals(ref Controller other) {
		return device_id == other.device_id;
	} //opEquals

} //Controller

struct ControllerBind {

	int button;
	KeyDelegate func;
	KeyState state;

} //ControllerBind

struct ControllerAxis {

	SDL_GameControllerAxis axis;
	AxisDelegate func;

} //ControllerAxis

struct EventSpec {

	EventDelegate ed;
	EventMask mask;
	alias ed this;

} //EventSpec

enum AnyKey = -1;
alias EventMask = ulong;

immutable SDL_EventType[45] sdl_events = [
	SDL_FIRSTEVENT,
	SDL_QUIT,
	SDL_APP_TERMINATING,
	SDL_APP_LOWMEMORY,
	SDL_APP_WILLENTERBACKGROUND,
	SDL_APP_DIDENTERBACKGROUND,
	SDL_APP_WILLENTERFOREGROUND,
	SDL_APP_DIDENTERFOREGROUND,
	SDL_WINDOWEVENT,
	SDL_SYSWMEVENT,
	SDL_KEYDOWN,
	SDL_KEYUP,
	SDL_TEXTEDITING,
	SDL_TEXTINPUT,
	SDL_MOUSEMOTION,
	SDL_MOUSEBUTTONDOWN,
	SDL_MOUSEBUTTONUP,
	SDL_MOUSEWHEEL,
	SDL_JOYAXISMOTION,
	SDL_JOYBALLMOTION,
	SDL_JOYHATMOTION,
	SDL_JOYBUTTONDOWN,
	SDL_JOYBUTTONUP,
	SDL_JOYDEVICEADDED,
	SDL_JOYDEVICEREMOVED,
	SDL_CONTROLLERAXISMOTION,
	SDL_CONTROLLERBUTTONDOWN,
	SDL_CONTROLLERBUTTONUP,
	SDL_CONTROLLERDEVICEADDED,
	SDL_CONTROLLERDEVICEREMOVED,
	SDL_CONTROLLERDEVICEREMAPPED,
	SDL_FINGERDOWN,
	SDL_FINGERUP,
	SDL_FINGERMOTION,
	SDL_DOLLARGESTURE,
	SDL_DOLLARRECORD,
	SDL_MULTIGESTURE,
	SDL_CLIPBOARDUPDATE,
	SDL_DROPFILE,
	SDL_AUDIODEVICEADDED,
	SDL_AUDIODEVICEREMOVED,
	SDL_RENDER_TARGETS_RESET,
	SDL_RENDER_DEVICE_RESET,
	SDL_USEREVENT,
	SDL_LASTEVENT
];

struct InputHandler {

	import core.stdc.stdio : printf;
	import blindfire.engine.collections : Array, HashMap;
	import blindfire.engine.memory : IAllocator;

	enum INITIAL_SIZE = 8;

	private {

		IAllocator allocator_;

		SDL_Event ev;
		Array!EventSpec delegates;
		Array!MouseBind mouse_events;
		Array!MouseBind motion_events;
		Array!KeyBind input_events;
		Array!KeyBind key_events;

		Array!Controller controllers;
		Array!ControllerBind controller_binds;
		Array!ControllerAxis controller_axis_binds;

		HashMap!(SDL_EventType, EventMask) event_mask_;

		//mutated by SDL2
		Uint8* pressed_keys;

		//mouse pos, last first, current second
		int[2] last_x, last_y;

	}

	@property int mouse_x() const { return last_x[0]; }
	@property int mouse_y() const { return last_y[0]; }

	void mouse_pos(out int x, out int y) const {
		x = last_x[0];
		y = last_y[0];
	} //mouse_pos

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;

		/* mouse and keyboard events */
		this.delegates = typeof(delegates)(allocator_, INITIAL_SIZE);
		this.mouse_events = typeof(mouse_events)(allocator_, INITIAL_SIZE);
		this.motion_events = typeof(motion_events)(allocator_, INITIAL_SIZE);
		this.input_events = typeof(input_events)(allocator_, INITIAL_SIZE);
		this.key_events = typeof(key_events)(allocator_, INITIAL_SIZE);

		/* controller events */
		this.controllers = typeof(controllers)(allocator_, INITIAL_SIZE);
		this.controller_binds = typeof(controller_binds)(allocator_, INITIAL_SIZE);
		this.controller_axis_binds = typeof(controller_axis_binds)(allocator_, INITIAL_SIZE);

		/* set up hashmap for holding event type to mask translation */
		this.event_mask_ = typeof(event_mask_)(allocator_, sdl_events.length);
		this.initializeMask();

		/* initialize pressed keys */
		this.pressed_keys = SDL_GetKeyboardState(null);

	} //this

	void initializeMask() {

		foreach (i, e; sdl_events) {
			EventMask n = i ^ 2;
			event_mask_[e] = n;
		}

	} //initializeMask

	ref typeof(this) addListener(EventDelegate ed) {

		delegates ~= EventSpec(ed, EventMask.max);

		return this;

	} //addListener

	/* filtering addListener, combines all types sent in to form single mask */
	ref typeof(this) addListener(SDL_EventType...)(EventDelegate ed, SDL_EventType types) {

		auto mask = 0;
		foreach (t; types) {
			mask |= 1 << event_mask_[t];
		}

		delegates ~= EventSpec(ed, mask);

		return this;

	} //addListener

	ref typeof(this) bindKeyEvent(SDL_Scancode key, KeyDelegate kd) {

		KeyBind kb = {key: key, func: kd};
		input_events ~= kb;

		return this;

	} //bindKeyEvent

	ref typeof(this) bindControllerBtn(SDL_GameControllerButton btn, KeyDelegate fn, KeyState st) {

		ControllerBind cb = {button: btn, func: fn, state: st};
		controller_binds ~= cb;

		return this;

	} //bindControllerBtn

	ref typeof(this) bindControllerAxis(SDL_GameControllerAxis ax, AxisDelegate fn) {

		ControllerAxis axis_bind = {axis: ax, func: fn};
		controller_axis_binds ~= axis_bind;

		return this;

	} //bindControllerAxis

	ref typeof(this) bindMouseBtn(Uint8 button, MouseDelegate md, KeyState state) {

		MouseBind mb = {mousebtn: button, func: md, state: to!MouseKeyState(state)};
		mouse_events ~= mb;

		return this;

	} //bindMouseBtn

	ref typeof(this) bindKey(SDL_Scancode key, KeyDelegate kd) {

		KeyBind kb = {key: key, func: kd};
		key_events ~= kb;

		return this;

	} //bindKey

	ref typeof(this) bindMouseMov(MouseDelegate md) {

		MouseBind mb = {mousebtn: 0, func: md};
		motion_events ~= mb;

		return this;

	} //bindMouseMov

	void handleEvents() {

		while(SDL_PollEvent(&ev)) {

			switch (ev.type) {

				case SDL_KEYDOWN, SDL_KEYUP:
					foreach (ref bind; input_events) {
						if (ev.key.keysym.scancode == bind.key) {
							if (bind.state == ev.key.state) {
								bind.func();
							}
						}
					}
					break;

				case SDL_MOUSEBUTTONDOWN, SDL_MOUSEBUTTONUP:
					foreach (ref bind; mouse_events) {
						if (ev.button.button == bind.mousebtn) {
							if (bind.state == ev.type) {
								bind.func(ev.motion.x, ev.motion.y);
							}
						}
					}
					break;

				case SDL_MOUSEMOTION:
					break;

				case SDL_CONTROLLERBUTTONDOWN, SDL_CONTROLLERBUTTONUP:
					foreach (ref bind; controller_binds) {
						if (ev.cbutton.button == bind.button) {
							if (bind.state == ev.cbutton.state) {
								bind.func();
							}
						}
					}

					break;

				case SDL_CONTROLLERDEVICEADDED:

					/* add controller to devices */
					auto new_device = SDL_GameControllerOpen(ev.cdevice.which);
					controllers ~= Controller(ev.cdevice.which, new_device);

					break;

				case SDL_CONTROLLERDEVICEREMOVED:

					/* remove controller unplugged */
					foreach (ref c; controllers) {
						if (c.device_id == ev.cdevice.which) 
							SDL_GameControllerClose(c.handle);
					}

					auto removed = Controller(ev.cdevice.which);
					controllers.remove(removed);

					break;

				case SDL_CONTROLLERDEVICEREMAPPED:
					break;

				default:
					break;

			}

			/* forward events to listeners, filtered with a bitmask */
			foreach(ref receiver; delegates) {
				if ((receiver.mask >> event_mask_[ev.type]) & 1) {
					receiver.ed(ev);
				}
			}

		}

		/* handle joystick axis input each frame */
		foreach (ref bind; controller_axis_binds) {
			auto axis_value = SDL_GameControllerGetAxis(controllers[0].handle, bind.axis);
			bind.func(axis_value);
		}

		/* keys pressed each frame */
		foreach (ref bind; key_events) {
			if (pressed_keys[bind.key] || bind.key == AnyKey) {
				bind.func();
			}
		}

		SDL_GetMouseState(&last_x[1], &last_y[1]);
		if (last_x[0] != last_x[1] || last_y[0] != last_y[1]) {

			last_x[0] = last_x[1];
			last_y[0] = last_y[1];

			//call only if change occured
			foreach (ref bind; motion_events) {
				bind.func(last_x[1], last_y[1]);
			}

		}

	} //handleEvents

} //InputHandler
