module smidig.fsm;

import std.typecons : Tuple;

import tested : name;

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

mixin template FSM(FStateID[] in_states, FStateTuple[] in_transitions, StateFunc) {

	alias RunFunc = StateFunc;
	alias TransitionFunc = void delegate(FStateID target_state);
	alias TripleRunFunc = Tuple!(TransitionFunc, "enter", RunFunc, "execute", TransitionFunc, "leave");

	FStateID current_state_ = -1;
	TripleRunFunc[in_states.length] states_;

	ref typeof(this) setInitialState(FStateID state) {

		transitionTo(state);

		return this;

	} //setInitialState

	ref typeof(this) attachState(S)(S state) {

		states_[state.id] = TripleRunFunc(&state.enter, &state.execute, &state.leave);

		return this;

	} //attachState

	void tick(Args...)(Args args) {

		states_[current_state_].execute(this, args);

	} //tick

	void transitionTo(FStateID new_state) {

		assert(new_state >= 0 && new_state < states_.length, "state outside range of existing states.");
		assert(new_state != current_state_, "tried to switch state to current.");

		if (current_state_ != -1) states_[current_state_].leave(new_state);
		states_[new_state].enter(current_state_);
		current_state_ = new_state;

	} //transitionTo

} //FSM

version(unittest) {

	import std.stdio : writefln;

	struct FSMTest {

		enum State : FStateID {
			Walking,
			Running
		} //State

		alias StateFun = void delegate(ref FSMTest fsm);

		mixin FSM!([State.Walking, State.Running],
				   [FStateTuple(State.Walking, State.Running), FStateTuple(State.Running, State.Walking)],
				   StateFun);

		private {

			Walking walking_;
			Running running_;

		}

		@disable this();

		this (int v) {

			attachState(walking_);
			attachState(running_);

			setInitialState(State.Walking);

		} //this

		static struct Walking {

			enum id = State.Walking;

			void enter(FStateID from) {

			} //enter

			void execute(ref FSMTest fsm) {

				fsm.transitionTo(State.Running);

			} //execute

			void leave(FStateID to) {

			} //leave

		} //Walking

		static struct Running {

			enum id = State.Running;

			void enter(FStateID from) {

			} //enter

			void execute(ref FSMTest fsm) {

				fsm.transitionTo(State.Walking);

			} //execute

			void leave(FStateID to) {

			} //leave

		} //Running

	} //FSMTest

}

@name("FSM 1 (unimplemented)")
unittest {

	import std.string : format;

	auto fsm = FSMTest(10);
	fsm.tick();

	assert(0);

}
