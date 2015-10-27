module blindfire.engine.fsm;

import std.typecons : Tuple;

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

mixin template FSM(FStateID[] in_states, FStateTuple[] in_transitions, StateFunc) {

	alias RunFunc = StateFunc;
	alias TransitionFunc = void delegate(FStateID target_state);
	alias TripleRunFunc = Tuple!(TransitionFunc, "enter", RunFunc, "execute", TransitionFunc, "leave");

	//memory related madness
	void* last_this_;
	ptrdiff_t[3][in_states.length] state_offsets_; //used to make sure shit doesn't break

	FStateID current_state_ = -1;
	TripleRunFunc[in_states.length] states_;

	this(this) {
		readjustPointers();
	} //this(this)

	ref typeof(this) setInitialState(FStateID state) {

		last_this_ = &this;
		transitionTo(state);

		return this;

	} //setInitialState

	ref typeof(this) attachState(S)(S state) {

		state_offsets_[state.id] = [
			(&state.enter).ptr - &this,
			(&state.execute).ptr - &this,
			(&state.leave).ptr - &this
		];

		states_[state.id] = TripleRunFunc(&state.enter, &state.execute, &state.leave);

		return this;

	} //attachState

	void tick(Args...)(Args args) {

		states_[current_state_].execute(this, args);

	} //tick

	void readjustPointers() {

		foreach (id, ref triple; states_) {
			triple.enter.ptr = state_offsets_[id][0] + cast(void*)&this;
			triple.execute.ptr = state_offsets_[id][1] + cast(void*)&this;
			triple.leave.ptr = state_offsets_[id][2] + cast(void*)&this;
		}

	} //readjustPointers

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

		alias StateFun = void delegate(ref FSMTest fsm, void** ptr);

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

			void execute(ref FSMTest fsm, void** ptr) {

				*ptr = &fsm;
				fsm.transitionTo(State.Running);

			} //execute

			void leave(FStateID to) {

			} //leave

		} //Walking

		static struct Running {

			enum id = State.Running;

			void enter(FStateID from) {

			} //enter

			void execute(ref FSMTest fsm, void** ptr) {

				*ptr = &fsm;
				fsm.transitionTo(State.Walking);

			} //execute

			void leave(FStateID to) {

			} //leave

		} //Running

	} //FSMTest

}

unittest {

	import std.string : format;
	import std.algorithm : move;

	void* last_this, current_this;

	auto fsm = FSMTest(10);
	fsm.tick(&last_this);

	auto new_fsm = fsm;
	new_fsm.tick(&current_this);

	assert(last_this != current_this, 
		format("last_this:%s was equal to current_this:%s, didn't move?", last_this, current_this));

}
