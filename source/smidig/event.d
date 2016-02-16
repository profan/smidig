module smidig.event;

import tested : name;

alias EventID = uint;
alias EventCast = Event!(255, uint);
alias EventDelegate = void delegate(EventCast*);
enum EventMemory = 1024 * 1024 * 2; //allocate two megabytes

struct Event(EventID ID, T) {

	EventCast* next; // for intrusive container purposes

	this(T t) {
		payload = t;
	} //this

	enum message_id = ID;
	alias payload this;
	T payload;

	@property OT* extract(OT)() { //TODO check if this still is necessary, probably not?
		return cast(OT*)(&this);
	} //extract

	import std.string : format;
	static assert(this.sizeof <= 32u, format("Event: %s too big: %d", typeof(this).stringof, this.sizeof));

} //Event

struct EventManager {

	import smidig.collections : Array, ILinkedList;
	import smidig.memory : IAllocator, Mallocator, theAllocator, Region, make, dispose;

	IAllocator allocator_;
	Region!Mallocator region_allocator_;

	Array!(Array!EventDelegate) delegates_;
	Array!(ILinkedList!EventCast) events_;

	@disable this();
	@disable this(this);

	this(size_t to_allocate, EventID number_types) {

		import smidig.memory : construct;

		auto num_to_alloc = number_types + 1;

		this.allocator_ = theAllocator;
		this.region_allocator_ = Region!Mallocator(to_allocate);

		this.delegates_ = typeof(delegates_)(allocator_, num_to_alloc);
		this.delegates_.length = this.delegates_.capacity;

		this.events_ = typeof(events_)(allocator_, num_to_alloc);
		this.events_.length = this.events_.capacity;

		foreach (i, ref arr; delegates_) {
			arr.construct(allocator_, 8);
		}

		assert(events_.length != 0);
		assert(delegates_.length != 0);
		assert(allocator_, "allocator was null?");

	} //this

	~this() {

		if (allocator_) {

			import std.stdio : writefln;
			debug writefln("Destroying EventManager");

		}

	} //~this

	/**
	 * Instantiates a new $(D Event) of type $(D E) with the given arguments.
	*/
	void push(E, Args...)(Args args) {

		auto thing = region_allocator_.make!(E)(args);
		events_[thing.message_id] ~= cast(EventCast*)thing;

	} //push

	/**
	 * Pushes an event to the list of events, copying the event into the bump-allocated space.
	*/
	void push(E)(ref E e) {

		auto allocated_space = region_allocator_.make(E)();
		*allocated_space = e;
		events_[e.message_id] ~= cast(EventCast*)allocated_space;

	} //push

	/**
	 * Checks if passed delegate $(D ED) can be called with the given event $(D T) as a parameter.
	*/
	static mixin template checkValidity(T, ED) {

		import std.traits : isImplicitlyConvertible, ParameterTypeTuple;
		alias first_param = ParameterTypeTuple!(ED)[0];

		static assert (isImplicitlyConvertible!(T, first_param),
					   "can't call function: " ~ ED.stringof ~ " with: " ~ T.stringof);

	} //checkValidity

	/**
	 * Registers an event delegate for a given event type.
	*/
	void register(E, ED)(ED dele) {

		mixin checkValidity!(E, ED);
		delegates_[E.message_id] ~= cast(EventDelegate)dele;

	} //register

	/**
	 * Deregisters a given delegate from an event type handler.
	*/
	void unregister(E, ED)(ED base_dele) { //CAUUTIIOON

		auto dele = cast(EventDelegate) base_dele;
		delegates_[E.message_id].remove(dele);

	} //unregister

	/**
	 * Directly calls the delegates registered for the given $(D Event).
	*/
	void fire(E, Args...)(Args args) {

		alias ED = void delegate(ref E);
		mixin checkValidity!(E, ED);

		auto event = E(args);
		auto cur_dels = delegates_[E.message_id][];

		foreach (key, ref del_func; cur_dels) {
			auto casted_func = cast(ED) del_func;
			casted_func(event);
		}

	} //fire

	/**
	 * Schedules an event to be fired off in x number of ticks.
	*/
	void schedule(size_t in_ticks) { //TODO implement

	} //schedule

	mixin template doTick() {

		/**
		 * Dispatches all queued events for the given frame,
		 * calling all the registered delegates for each $(D Event) type.
		*/
		static void tick(EventTypes...)(ref EventManager ev_man) {

			import core.stdc.stdio : printf;

			foreach (id, ref ev_list; ev_man.events_) {

				if (ev_list.empty) continue;
				auto cur_dels = ev_man.delegates_[id][];
				if (cur_dels.length == 0) {
					ev_list.clear();
					continue;
				}

				foreach (ev; ev_list) {
					foreach (key, ref del_func; cur_dels) {

						event_switch: switch (id) {
							//static foreach, generates code for each event type
							foreach (type; EventTypes) {
								case type.message_id:
									auto casted_func = cast(void delegate(ref type)) del_func;
									auto event = ev.extract!type;
									casted_func(*event);
									break event_switch;
							}
							default: printf("unhandled event type: %d", id);
						}

					}
				}

				ev_list.clear();

			}

			// since it's a region allocator, its just a pointer bump
			ev_man.region_allocator_.deallocateAll();

		} //tick

	} //doTick

} //EventManager

version (unittest) {

	import std.stdio : writefln;
	import std.meta : AliasSeq;
	import std.format : format;

	enum TestEvent : EventID {
		Foo,
		Bar
	}

	alias FooEvent = Event!(TestEvent.Foo, bool);
	alias BarEvent = Event!(TestEvent.Bar, long);

	alias TestEventTypes = AliasSeq!(FooEvent, BarEvent);
	mixin EventManager.doTick;

}

@name("EventManager 1: test deferred sending and recieving with register+push")
unittest {

	auto evman = EventManager(EventMemory, TestEvent.max);

	auto received_result = false;
	auto func = (ref FooEvent foo) { received_result = foo; };
	evman.register!FooEvent(func);
	evman.push!FooEvent(true);

	tick!TestEventTypes(evman);
	assert(received_result, format("received_result wasn't %s, event not received properly?", true));

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
	}
	tick!TestEventTypes(evman);
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

@name("EventManager 5: perf test for several event types (unimplemented)")
unittest {

	import std.datetime : StopWatch;
	assert(0);

}

@name("EventManager 6: perf test of many delegates (unimplemented)")
unittest {

	assert(0);

}
