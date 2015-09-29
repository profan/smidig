module blindfire.engine.event;

alias EventID = uint;
alias EventCast = Event!(255, uint);
alias EventDelegate = void delegate(EventCast*);
enum EventMemory = 1024 * 1024 * 2; //allocate two megabytes

struct Event(EventID ID, T) {
	enum message_id = ID;
	alias payload this;
	T payload;

	@property OT* extract(OT)() {
		return cast(OT*)(&this);
	} //extract

	import std.format : format;
	static assert(this.sizeof <= 32u, format("Event: %s too big: %d", typeof(this).stringof, this.sizeof));
} //Event

struct EventManager {

	import std.stdio : writefln;
	import blindfire.engine.memory : LinearAllocator;

	@disable this();
	@disable this(this);

	LinearAllocator allocator;
	EventDelegate[][] delegates;
	EventCast*[][] events;

	this(size_t to_allocate, EventID number_types) {

		this.allocator = LinearAllocator(to_allocate, "EventAllocator");
		this.delegates = new EventDelegate[][](number_types+1, 0);
		this.events = new EventCast*[][](number_types+1, 0);

	} //this

	void push(E, Args...)(Args args) {

		auto thing = allocator.alloc!(E)(args);
		events[thing.message_id] ~= cast(EventCast*)thing;

	} //push

	void push(E)(ref E e) {

		import orb.memory : get_size;

		auto allocated_space = cast(E*)allocator.alloc(get_size!E(), E.alignof);
		*allocated_space = e;
		events[e.message_id] ~= cast(EventCast*)allocated_space;

	} //push

	static mixin template checkValidity(T, ED) {

		import std.traits : isImplicitlyConvertible, ParameterTypeTuple;
		alias first_param = ParameterTypeTuple!(ED)[0];

		static assert (isImplicitlyConvertible!(T, first_param),
					   "can't call function: " ~ ED.stringof ~ " with: " ~ T.stringof);

	} //checkValidity

	void register(T, ED)(ED dele) {
		mixin checkValidity!(T, ED);
		delegates[T.message_id] ~= cast(EventDelegate)dele;
	} //register

	void unregister(T, ED)(ED base_dele) { //CAUUTIIOON
		import std.algorithm : remove;
		auto dele = cast(EventDelegate) base_dele;
		delegates[T.message_id][].remove!(e => e == dele);
	} //unregister

	void test(T)(size_t rounds) {

		import std.range : iota;
		import std.datetime : StopWatch;

		alias TestEvent = Event!(0, uint);

		void receiveSomeEvent(EventCast* event) {
			auto ev = event.extract!TestEvent;
		}

		auto sw = StopWatch();

		register!TestEvent(&receiveSomeEvent);

		sw.start();
		foreach (i; iota(0, rounds)) {
			push!TestEvent(10);
			tick!T();
		}
		sw.stop();

		unregister!TestEvent(&receiveSomeEvent);

		writefln("Sending and Receiving %s events took: %s msecs", rounds, sw.peek.msecs);

	} //test

	void fire() { //TODO implement

	} //fire

	void schedule() { //TODO implement

	} //schedule

	mixin template doTick() {

		static string doSwitchEntry(alias EventTypes)() {

			import std.conv : to;
			import std.string : format;

			auto str = "";
			foreach (type, id; EventTypes) {

				str ~= format(
					q{case %d:
						auto casted_func = cast(void delegate(ref %s)) del_func;
						auto event = ev.extract!(%s); casted_func(*event);
						break;
					}, id, type, type);

			}

			return str;

		} //doSwitchEntry

		static void tick(alias EvTypesMap)(ref EventManager ev_man) {

			foreach (id, ref ev_list; ev_man.events) {

				if (ev_list.length == 0) continue;
				auto cur_dels = ev_man.delegates[id];

				if (cur_dels.length > 0) {
					foreach (ref ev; ev_list) {
						foreach (key, ref del_func; cur_dels) {
							switch (id) {
								mixin(doSwitchEntry!EvTypesMap());
								default: writefln("unhandled event type: %d", id);
							}
						}
					}
				}

				ev_list.length = 0;

			}

			ev_man.allocator.reset();

		} //tick

	} //doTick

} //EventManager

template expandEventsToMap(string name, Events...) {
	enum expandEventsToMap =
		"enum : int[string] {
			" ~ name ~ " = [" ~ expandEvents!Events ~ "]
		}";
} //expandEventsToMap

template expandEvents(Events...) {
	import std.conv : to;
	static if (Events.length > 1) {
		enum expandEvents = expandEvents!(Events[0..1]) ~ ", "
			~ expandEvents!(Events[1..$]);
	} else static if (Events.length > 0) {
		enum expandEvents = "\"" ~ Events[0].stringof ~ "\" : " ~ to!string(Events[0].message_id)
			~ expandEvents!(Events[1..$]);
	} else {
		enum expandEvents = "";
	}
} //expandEvents

version (unittest) {

	import std.stdio : writefln;

	enum TestEvent : EventID {
		Foo,
		Bar
	}

	alias FooEvent = Event!(TestEvent.Foo, bool);
	alias BarEvent = Event!(TestEvent.Bar, long);

	mixin (expandEventsToMap!("TestEventIdentifier",
				  FooEvent,
				  BarEvent));

	mixin EventManager.doTick;

}

unittest {

	import std.string : format;

	auto evman = EventManager(EventMemory, TestEvent.max);

	auto received_result = false;
	auto func = (ref FooEvent foo) { received_result = foo; };
	evman.register!FooEvent(func);
	evman.push!FooEvent(true);

	tick!TestEventIdentifier(evman);
	assert(received_result == true, 
		   format("received_result wasn't %s, event not received properly?", true));

} //TODO write some tests up in this motherfucker
