module blindfire.ai;

import std.typecons : Tuple;
import std.stdio : writefln;

import blindfire.engine.fsm : FSM, FStateID, FStateTuple;

struct MovingFSM {

	alias MovingFunc = void delegate(ref MovingFSM fsm, int new_speed);

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

	private {

		Stationary stationary_;
		Moving moving_;

	}

	this(int initial_velocity) {

		setInitialState(State.Moving)
			.attachState(stationary_)
			.attachState(moving_);

	} //this

	static struct Stationary {

		enum id = State.Stationary;

		void enter(FStateID from) {

		} //enter

		void execute(ref MovingFSM fsm, int new_speed) {

		} //execute

		void leave(FStateID to) {

		} //leave

	} //Stationary

	static struct Moving {

		enum id = State.Moving;

		void enter(FStateID from) {

		} //enter

		void execute(ref MovingFSM fsm, int new_speed) {

		} //execute

		void leave(FStateID to) {

		} //leave

	} //Moving

} //WalkingFSM


