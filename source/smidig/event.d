module smidig.event;

import tested : name;

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

	import std.string : format;
	static assert(this.sizeof <= 32u, format("Event: %s too big: %d", typeof(this).stringof, this.sizeof));
} //Event

struct EventManager {

	import core.stdc.stdio : printf;
	import smidig.collections : Array;
	import smidig.memory : IAllocator, Mallocator, theAllocator, Region, make, dispose;

	IAllocator allocator_;
	Region!Mallocator region_allocator_;

	Array!(Array!EventDelegate*) delegates_;
	Array!(Array!(EventCast*)*) events;

	@disable this();
	@disable this(this);

	this(size_t to_allocate, EventID number_types) {

		auto num_to_alloc = number_types + 1;

		this.allocator_ = theAllocator;
		this.region_allocator_ = Region!Mallocator(to_allocate);
		this.delegates_ = typeof(delegates_)(allocator_, num_to_alloc);
		this.events = typeof(events)(allocator_, num_to_alloc);

		foreach (i; 0..num_to_alloc) {
			delegates_.add(allocator_.make!(Array!EventDelegate)(allocator_, 8));
			events.add(allocator_.make!(Array!(EventCast*))(allocator_, 8));
		}

	} //this

	~this() {

		foreach (ref arr; delegates_) {
			this.allocator_.dispose(arr);
		}

		foreach (ref arr; events) {
			this.allocator_.dispose(arr);
		}

	} //~this

	void push(E, Args...)(Args args) {

		auto thing = region_allocator_.make!(E)(args);
		(*events[thing.message_id]) ~= cast(EventCast*)thing;

	} //push

	void push(E)(ref E e) {

		auto allocated_thing = region_allocator_.make(E)();
		*allocated_space = e;
		(*events[e.message_id]) ~= cast(EventCast*)allocated_space;

	} //push

	static mixin template checkValidity(T, ED) {

		import std.traits : isImplicitlyConvertible, ParameterTypeTuple;
		alias first_param = ParameterTypeTuple!(ED)[0];

		static assert (isImplicitlyConvertible!(T, first_param),
					   "can't call function: " ~ ED.stringof ~ " with: " ~ T.stringof);

	} //checkValidity

	void register(E, ED)(ED dele) {
		mixin checkValidity!(E, ED);
		(*delegates_[E.message_id]) ~= cast(EventDelegate)dele;
	} //register

	void unregister(E, ED)(ED base_dele) { //CAUUTIIOON
		auto dele = cast(EventDelegate) base_dele;
		delegates_[E.message_id].remove(dele);
	} //unregister

	void fire(E, Args...)(Args args) {

		alias ED = void delegate(ref E);
		mixin checkValidity!(E, ED);

		auto event = E(args);
		auto cur_dels = (*delegates_[E.message_id])[];

		foreach (key, ref del_func; cur_dels) {
			auto casted_func = cast(ED) del_func;
			casted_func(event);
		}

	} //fire

	void schedule(size_t in_ticks) { //TODO implement

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

			import core.stdc.stdio : printf;

			foreach (id, ref ev_list; ev_man.events) {

				if (ev_list.length == 0) continue;
				auto cur_dels = (*ev_man.delegates_[id])[];

				if (cur_dels.length > 0) {
					foreach (ref ev; *ev_list) {
						foreach (key, ref del_func; cur_dels) {
							switch (id) {
								mixin(doSwitchEntry!EvTypesMap());
								default: printf("unhandled event type: %d", id);
							}
						}
					}
				}

				ev_list.clear();

			}

			ev_man.region_allocator_.deallocateAll();

		} //tick

	} //do_tick

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
	import std.string : format;

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

@name("EventManager 1: test deferred sending and recieving with register+push")
unittest {

	auto evman = EventManager(EventMemory, TestEvent.max);

	auto received_result = false;
	auto func = (ref FooEvent foo) { received_result = foo; };
	evman.register!FooEvent(func);
	evman.push!FooEvent(true);

	tick!TestEventIdentifier(evman);
	assert(received_result == true, 
		   format("received_result wasn't %s, event not received properly?", true));

} //TODO write some tests up in this motherfucker

@name("EventManager 2: test firing events and recieving with register+fire")
unittest {

	auto evman = EventManager(EventMemory, TestEvent.max);

	long received_result = 0;
	auto func = (ref BarEvent bar) { received_result = bar; };
	evman.register!BarEvent(func);
	evman.fire!BarEvent(25);

	assert(received_result == 25, format("received result wasn't %d, event not received properly?", 25));

}

@name("EventManager 3: perf test for deferred events")
unittest {

	import std.datetime : StopWatch;
	auto evman = EventManager(EventMemory, TestEvent.max);
	enum rounds = 100_000;

	auto sw = StopWatch();

	void receiveSomeEvent(ref FooEvent event) {}

	evman.register!FooEvent(&receiveSomeEvent);

	sw.start();
	foreach (i; 0..rounds) {
		evman.push!FooEvent(true);
		tick!TestEventIdentifier(evman);
	}
	sw.stop();

	writefln("[EventManager] took %s ms to push/tick %s events.", sw.peek().msecs, rounds);

}

@name("EventManager 4: perf test for fired events")
unittest {

	import std.datetime : StopWatch;
	auto evman = EventManager(EventMemory, TestEvent.max);
	enum rounds = 100_000;

	auto sw = StopWatch();

	void receiveSomeEvent(ref FooEvent event) {}

	evman.register!FooEvent(&receiveSomeEvent);

	sw.start();
	foreach (i; 0..rounds) {
		evman.fire!FooEvent(true);
	}
	sw.stop();

	writefln("[EventManager] took %s ms to fire %s events.", sw.peek().msecs, rounds);

}
