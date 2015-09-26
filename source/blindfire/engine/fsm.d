module blindfire.engine.fsm;

import std.typecons : Tuple;

mixin template makeStates(States) {

	void createStates() {

	}

} //makeStates

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

struct FSM(FStateID[] in_states, FStateTuple[] in_transitions, StateFunc) {

	alias RunFunc = StateFunc;

	private {
		RunFunc[in_states.length] states;
		immutable FStateTuple[] transitions = in_transitions;
	}

	@disable this(this);

	void attachFunction(FStateID id, RunFunc func) {

	}

	void onTransition(FStateID from, FStateID to) {

	}

	void transitionTo(FStateID new_state) {

	}

} //FSM

struct MovingFSM {

	alias MovingFunc = void delegate(int new_speed);

	enum States : FStateID {
		Moving,
		Stationary
	}

	mixin FSM!([States.Moving, States.Stationary], 
			   [FStateTuple(States.Moving, States.Stationary), 
			   FStateTuple(States.Stationary, States.Moving)],
			   MovingFunc);

} //WalkingFSM

enum TestState : FStateID {
	Connected,
	Disconnected
}

auto test_fsm =
	FSM!([TestState.Connected, TestState.Disconnected], //states
		 [FStateTuple(TestState.Connected, TestState.Disconnected), //transitions
		 FStateTuple(TestState.Disconnected, TestState.Connected)], void delegate())();