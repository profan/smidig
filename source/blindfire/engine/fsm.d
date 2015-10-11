module blindfire.engine.fsm;

import std.typecons : Tuple;

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

mixin template FSM(FStateID[] in_states, FStateTuple[] in_transitions, StateFunc) {

	alias RunFunc = StateFunc;
	alias TransitionFunc = void delegate(FStateID target_state);
	alias TripleRunFunc = Tuple!(TransitionFunc, "enter", RunFunc, "exec", TransitionFunc, "leave");

	FStateID current_state;
	TripleRunFunc[in_states.length] states;
	immutable FStateTuple[] transitions = in_transitions;

	ref typeof(this) setInitialState(FStateID state) {
		transitionTo(state);
		return this;
	} //setInitialState

	ref typeof(this) attachFunction(FStateID id, TransitionFunc enter, RunFunc exec, TransitionFunc leave) {
		states[id] = TripleRunFunc(enter, exec, leave);
		return this;
	} //attachFunction

	ref typeof(this) attachState(S)(FStateID id, S state) {
		states[id] = TripleRunFunc(&state.enter, &state.execute, &state.leave);
		return this;
	} //attachState

	void tick(Args...)(Args args) {
		states[current_state](args);
	} //tick

	void transitionTo(FStateID new_state) {

		assert(new_state >= 0 && new_state < states.length, "state outside range of existing states.");
		assert(new_state != current_state, "tried to switch state to current.");

		states[current_state].leave(new_state);
		states[new_state].enter(current_state);
		current_state = new_state;

	} //transitionTo

} //FSM

unittest {

}
