module blindfire.engine.eventhandler;

import derelict.sdl2.sdl;

alias void delegate(ref SDL_Event) EventDelegate;
alias void delegate() KeyDelegate;
alias void delegate(int, int) MouseDelegate;

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

enum AnyKey = -1;

struct EventHandler {

	import blindfire.engine.collections : Array;
	import blindfire.engine.memory : IAllocator;

	enum INITIAL_SIZE = 8;
	IAllocator allocator_;

	SDL_Event ev;
	Array!EventDelegate delegates;
	Array!MouseBind mouse_events;
	Array!MouseBind motion_events;
	Array!KeyBind input_events;
	Array!KeyBind key_events;

	//mutated by SDL2
	Uint8* pressed_keys;

	//mouse pos, last first, current second
	int[2] last_x, last_y;

	@property int mouse_x() const { return last_x[0]; }
	@property int mouse_y() const { return last_y[0]; }

	void mouse_pos(out int x, out int y) const {
		x = last_x[0];
		y = last_y[0];
	} //mouse_pos

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		this.delegates = typeof(delegates)(allocator, INITIAL_SIZE);
		this.mouse_events = typeof(mouse_events)(allocator, INITIAL_SIZE);
		this.motion_events = typeof(motion_events)(allocator, INITIAL_SIZE);
		this.input_events = typeof(input_events)(allocator, INITIAL_SIZE);
		this.key_events = typeof(key_events)(allocator, INITIAL_SIZE);
		this.allocator_ = allocator;

		this.pressed_keys = SDL_GetKeyboardState(null);

	} //this

	void add_listener(EventDelegate ed) {
		delegates ~= ed;
	} //add_listener

	void bind_keyevent(SDL_Scancode key, KeyDelegate kd) {
		KeyBind kb = {key: key, func: kd};
		input_events ~= kb;
	} //bind_keyevent

	void bind_mousebtn(Uint8 button, MouseDelegate md, KeyState state) {
		MouseBind mb = {mousebtn: button, func: md, state: to!MouseKeyState(state)};
		mouse_events ~= mb;
	} //bind_mousebtn

	void bind_key(SDL_Scancode key, KeyDelegate kd) {
		KeyBind kb = {key: key, func: kd};
		key_events ~= kb;
	} //bind_key

	void bind_mousemov(MouseDelegate md) {
		MouseBind mb = {mousebtn: 0, func: md};
		motion_events ~= mb;
	} //bind_mousemov

	void handle_events() {
		
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
				default:
					break;
			}
	
			foreach(ref receiver; delegates) {
				receiver(ev);
			}

		}

		foreach (ref bind; key_events) {
			if (pressed_keys[bind.key] || bind.key == AnyKey) {
				bind.func();
			}
		}

		SDL_GetMouseState(&last_x[1], &last_y[1]);
		foreach (ref bind; motion_events) {
			bind.func(last_x[1], last_y[1]);
		}

		if (last_x[0] != last_x[1] || last_y[0] != last_y[1]) {
			last_x[0] = last_x[1];
			last_y[0] = last_y[1];
		}

	} //handle_events

} //EventHandler
