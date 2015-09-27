module blindfire.ai;

import std.typecons : Tuple;
import std.stdio : writefln;

import blindfire.engine.fsm : FSM, FStateID, FStateTuple;

struct MovingFSM {

	alias MovingFunc = void delegate(int new_speed);

	enum State : FStateID {
		Moving,
		Stationary
	}

	@disable this();
	@disable this(this);

	mixin FSM!([State.Moving, State.Stationary], //states
			[FStateTuple(State.Moving, State.Stationary), //transitions
			FStateTuple(State.Stationary, State.Moving)],
			MovingFunc);

	this(int initial_velocity) {

		setInitialState(State.Moving)
			.attachFunction(State.Moving, &onMovEnter, &onMovExecute, &onMovLeave)
			.attachFunction(State.Stationary, &onStatEnter, &onStatExecute, &onStatLeave);

	} //this

	void onStatEnter(FStateID from) {
		writefln("entered stat");
	} //onStatEnter

	void onStatExecute(int new_speed) {
		writefln("got: %d", new_speed);
		transitionTo(State.Moving);
	} //onStatExecute

	void onStatLeave(FStateID target) {

	} //onStatLeave

	void onMovEnter(FStateID from) {

	} //onMovEnter

	void onMovExecute(int new_speed) {

	} //onMovExecute

	void onMovLeave(FStateID target) {

	} //onMovLeave

} //WalkingFSM


