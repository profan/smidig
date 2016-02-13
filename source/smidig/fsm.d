module smidig.fsm;

import std.typecons : Tuple;

import tested : name;

alias FStateID = int;
alias FStateTuple = Tuple!(FStateID, FStateID);

mixin template FSM(StateFunc, in_states...) {

	import std.meta : staticMap;
	import smidig.meta : Identifier;
	alias in_states_str = staticMap!(Identifier, in_states);

	private {

		static string generateTick(string args) {

			import std.array : appender;
			import std.format : format;

			auto app = appender!string();

			//generate switch case for tick
			foreach (state; in_states_str) {
				app ~= q{
					case %s.id:
						%s.execute(this, %s);
						break;
				}.format(state, state, args);
			}

			return app.data();

		} //generateTick

		static string generateSwitch(string cond, string data, string pre = "") {

			import std.array : appender;
			import std.format : format;

			auto app = appender!string();
			app ~= q{ %s final switch (%s) { %s }}.format(pre, cond, data);

			return app.data();

		} //generateSwitch

		static string generateTransitionTo(string args) {

			import std.array : appender;
			import std.format : format;

			auto app = appender!string();

			foreach (state; in_states_str) {
				app ~= q{
					case %s.id:
						%s.enter(current_state_);
						current_state_ = %s.id;
						break;
				}.format(state, state, state);
			}

			return app.data();

		} //generateTransitionTo

		static string generateLeaving(string args) {

			import std.array : appender;
			import std.format : format;

			auto app = appender!string();

			//only run leave if its in a valid state
			foreach (state; in_states_str) {
				app ~= q{
					case %s.id:
						%s.leave(%s);
						break;
				}.format(state, state, args);
			}

			return app.data();

		} //generateLeaving

	}

	alias RunFunc = StateFunc; //not used right now, probably would help
	alias TransitionFunc = void delegate(FStateID target_state);

	FStateID current_state_ = -1;

	void tick(Args...)(Args args) {
		mixin(generateSwitch(current_state_.stringof, generateTick("args")));
	} //tick

	void transitionTo(FStateID new_state) {
		mixin(generateSwitch(current_state_.stringof, generateLeaving(new_state.stringof), q{if (current_state_ != 1)}));
		mixin(generateSwitch(new_state.stringof, generateTransitionTo(new_state.stringof)));
	} //transitionTo

	void setState(FStateID state_id) {
		current_state_ = state_id;
	} //setState

} //FSM

version(unittest) {

	import std.stdio : writefln;

	struct FSMTest {

		enum State : FStateID {
			Walking,
			Running
		} //State

		alias StateFun = void delegate(ref FSMTest fsm);

		private {

			Walking walking_;
			Running running_;

		}

		mixin FSM!(StateFun, walking_, running_);

		@disable this();
		@disable this(this);

		this(int v) {

			setState(State.Walking);

		} //this

		static struct Walking {

			enum id = State.Walking;

			void enter(FStateID from) {

			} //enter

			void execute(ref FSMTest fsm, int v) {

				writefln("walking got value: %d", v);
				fsm.transitionTo(State.Running);

			} //execute

			void leave(FStateID to) {

				writefln("left walking for: %d", to);

			} //leave

		} //Walking

		static struct Running {

			enum id = State.Running;

			void enter(FStateID from) {

				writefln("entered running from: %d", from);

			} //enter

			void execute(ref FSMTest fsm, int v) {

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
	fsm.tick(10);

	assert(0);

}
