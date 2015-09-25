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

	private {
		LinearAllocator allocator;
		EventDelegate[][EventID] delegates;
		EventCast*[][EventID] events;
	}

	this(size_t to_allocate) {
		this.allocator = LinearAllocator(to_allocate, "EventAllocator");
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

	void register(T)(EventDelegate dele) {
		delegates[T.message_id] ~= dele;
	} //register

	void unregister(T)(EventDelegate dele) {
		import std.algorithm : remove;
		delegates[T.message_id][].remove!(e => e == dele);
	} //unregister

	void test(size_t rounds) {

		alias TestEvent = Event!(0, uint);

		void receiveSomeEvent(EventCast* event) {
			auto ev = event.extract!TestEvent;
		}

		import std.range : iota;
		import std.datetime : StopWatch;

		auto sw = StopWatch();

		register!TestEvent(&receiveSomeEvent);

		sw.start();
		foreach (i; iota(0, rounds)) {
			push!TestEvent(10);
			tick();
		}
		sw.stop();

		unregister!TestEvent(&receiveSomeEvent);

		writefln("Sending and Receiving %s events took: %s msecs", rounds, sw.peek.msecs);

	} //test

	void fire() {

	} //fire

	void tick() {
		foreach (id, ref ev_list; events) {
			if (auto del_ptr = id in delegates) {
				foreach (ref ev; ev_list) {
					foreach (key, ref del_func; *del_ptr) {
						del_func(ev);
					}
				}
			}
			ev_list.length = 0;
		}
		allocator.reset();
	} //tick

} //EventManager

unittest {

} //TODO write some tests up in this motherfucker
