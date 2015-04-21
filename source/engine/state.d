module blindfire.engine.state;

import blindfire.engine.eventhandler;
import blindfire.engine.window;

alias StateID = ulong;

enum State {

	MENU,
	JOIN,
	GAME,
	OPTIONS,
	LOBBY,
	WAIT

} //State

class GameStateHandler {

	GameState[] stack;
	GameState[StateID] states;

	this() {
		//asd
	}

	void add_state(GameState state, State type) {
		states[type] = state;
	}

	void push_state(State state) {
		GameState st = states[state];
		st.enter(); //entering the state
		stack ~= st;
	}

	GameState pop_state() {
		GameState st = stack[$-1];
		st.leave(); //leaving the state, do exit stuff
		stack = stack[0..$-1];
		stack[$-1].enter(); //entering the state now on top of stack
		return st;
	}

	void update(double dt) {
		stack[$-1].update(dt);
	}

	void draw(Window* window) {
		stack[$-1].draw(window);
	}

} //GameStateHandler

interface GameState {

	void enter();
	void leave();

	void update(double dt);
	void draw(Window* window);

} //GameState

unittest {
	//test some things
}
