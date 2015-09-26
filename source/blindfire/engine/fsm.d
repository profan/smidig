module blindfire.engine.fsm;

import std.typecons : Tuple;

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

mixin template FSM(FStateID[] in_states, FStateTuple[] in_transitions, StateFunc) {

	import std.traits : ParameterTypeTuple;

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

	ref typeof(this) attachFunction(FStateID id, TripleRunFunc func_triple) {
		states[id] = func_triple;
		return this;
	} //attachFunction

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