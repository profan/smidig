module smidig.memory.pool;

import std.stdio : writefln;

import smidig.meta : hasMember;
import smidig.memory.pointer;

import tested : name;

/* in-place construction, it's a bit ergh. */
void construct(T, Args...)(ref T thing, auto ref Args args)
	if (is(T == struct))
{

	thing.__ctor(args);

} //construct

void reinitialize(ClassName, CtorArgs...)(ClassName obj, CtorArgs args) {

	assert(typeid(obj) == typeid(ClassName), "Don't use this on interfaces or base classes!");
	static if (hasMember!(obj, "__dtor")) {
		obj.__dtor();
	}

	(cast(void*) obj)[0 .. typeid(obj).init.length] = typeid(obj).init[];
	static if (hasMember!(obj, "__ctor")) {
		obj.__ctor(args);
	}

} //reinitialize (thanks Destructionator)

@name("reinitialize 1 (unimplemented)")
unittest {

}

mixin template PoolCommon(T) {

	struct Item {
		T payload;
		alias payload this;
		bool active = false;
	} //Item

} //PoolCommon

struct ContinousPool(T) {

} //ContinousPool

struct ObjectPool(T, uint ExpandSize = 10, Args...) {

	import smidig.collections : Array;
	import smidig.memory : IAllocator, make, dispose;

	mixin PoolCommon!T;

	private{

		IAllocator allocator_;
		Array!Item pool_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size) {

		this.allocator_ = allocator;
		this.pool_ = typeof(pool_)(allocator_, initial_size);
		this.expand(initial_size);

	} //this

	~this() {

		foreach (e; pool_) {
			this.allocator_.dispose(e.payload);
		}

	} //~this

	void expand(size_t extra_space) {

		writefln("[ObjectPool] pool_.length: %s, new limit: %s", pool_.length, pool_.length + extra_space);
		for (size_t i = 0; i < extra_space; ++i) {
			pool_ ~= Item(allocator_.make!T(Args));
		}

	} //expand

	auto find_free_object() {

		size_t id = 0;

		if (pool_.length < id+1) {
			expand(ExpandSize);
		}

		while (pool_[id].active) {
			id += 1;
		}

		return id;

	} //findFreeObject

	auto create(Args...)(Args args) {

		auto id = find_free_object();
		auto obj = &pool_[id];
		reinitialize(obj, args);
		obj.active = true;

		return SmartPointer!(Item, release)(obj);

	} //create

	static void release(Item* object) {

		object.active = false;

	} //release

} //ObjectPool

version(unittest) {

	class PooledThing {

		int var = 5;

		this(int v) {
			this.var = v;
		}

	} //PooledThing

}

@name("ObjectPool 1: simple creation test")
unittest {

	import std.range : iota;
	import std.random : uniform;

	import smidig.memory : theAllocator;

	enum total_runs = 1000;
	auto pool = ObjectPool!(PooledThing, 1000, 0)(theAllocator, 32);

	foreach (i; iota(total_runs)) {
		auto v = uniform(int.min, int.max);
		auto thing = pool.create(v);
		assert(thing.var == v, "var in object didn't match v");
	}

}

