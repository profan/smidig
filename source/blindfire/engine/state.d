module blindfire.engine.state;

import blindfire.engine.window;

alias StateID = ulong;

class GameStateHandler {

	GameState[] stack;
	GameState[StateID] states;

	this() {
		//asd
	} //this

	void addState(GameState state) nothrow {
		states[state.id] = state;
	} //addState

	void pushState(StateID state) {
		GameState st = states[state];
		st.enter(); //entering the state
		stack ~= st;
	} //pushState

	GameState popState() {
		GameState st = stack[$-1];
		st.leave(); //leaving the state, do exit stuff
		stack = stack[0..$-1];
		stack[$-1].enter(); //entering the state now on top of stack
		return st;
	} //popState

	void switchState(StateID state) {
		stack[$-1].leave();
		stack[$-1] = states[state];
		stack[$-1].enter();
	} //switchState

	void update(double dt) {
		stack[$-1].update(dt);
	} //update

	void draw(Window* window) {
		stack[$-1].draw(window);
	} //draw

	GameState peek() nothrow {
		return stack[$-1];
	} //peek

} //GameStateHandler

interface GameState {

	@property StateID id() const nothrow @nogc;

	void enter();
	void leave();

	void update(double dt);
	void draw(Window* window);

} //GameState

unittest {
	//test some things
}
