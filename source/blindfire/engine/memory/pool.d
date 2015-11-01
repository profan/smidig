module blindfire.engine.memory.pool;

import blindfire.engine.meta : hasMember;

import std.stdio : writefln;

/* in-place construction, it's a bit ergh. */
void construct(T, Args...)(ref T thing, Args args)
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

	import blindfire.engine.collections : Array;
	import blindfire.engine.memory : IAllocator, make, dispose;

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

unittest {

	import std.range : iota;
	import std.random : uniform;

	import blindfire.engine.memory : theAllocator;

	enum total_runs = 1000;
	auto pool = ObjectPool!(PooledThing, 1000, 0)(theAllocator, 32);

	foreach (i; iota(total_runs)) {
		auto v = uniform(int.min, int.max);
		auto thing = pool.create(v);
		assert(thing.var == v, "var in object didn't match v");
	}

}

struct Data(T) {

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	Type object;
	uint ref_count;
	uint weak_count;
	alias object this;

} //Data

mixin template AddForward(string data) {
	@property auto opDispatch(string name)() {
		return mixin(data ~ "." ~ name);
	}
	@property auto opDispatch(string name, Args...)(Args args) {
		return mixin(data ~ "." ~ name)(args);
	}
}

struct SmartPointer(T) {

	import blindfire.engine.memory : IAllocator, make, dispose;

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	private {

		IAllocator allocator_;

		Data!(T)* data;

	}

	@property ref auto get() { return data.object; }
	@disable this(); //no default construction
	alias conv this;

	this(Args...)(IAllocator allocator, Args args) {
		allocator_ = allocator;
		data = allocator_.make!(Data!T)();
		data.object = allocator_.make!T(args);
		data.ref_count = 1;
		data.weak_count = 0;
		//writefln("[SmartPointer] acquired object: %s", data.object);
	} //this

	this(Data!(T)* other_data) {
		data = other_data;
		data.ref_count += 1;
	} //this(Data!T*)

	this(ST)(Data!(ST)* other_data)
		if (is(other_data.Type : Type))
		{
			data = cast(Data!(T)*)other_data;
			data.ref_count += 1;
			//writefln("[SmartPointer] copied object data explicitly: %s", data.object);
	} //this(Data!ST*)

	this(S)(SmartPointer!(S) s)
		if (is(s.Type : Type))
		{
			data = s.data;
			data.ref_count += 1;
			//writefln("[SmartPointer] converted from object: %s", s.data.object);
	} //this(S, F)

	this(this) {
		data = data;
		data.ref_count += 1;
		//writefln("[SmartPointer] copied object: %s", data.object);
	} //this(this)

	auto conv(S)() {
		return SmartPointer!(S)(this.data);
	} //conv

	void opAssign(S, F)(SmartPointer!(S) s)
		if (is(s.Type:Type)) 
	{
		if (data != s.data) {
			doDestroy();
		}
		data = s.data;
		data.ref_count += 1;
		//writefln("[SmartPointer] converted from object: %s", s.data.object);
	} //opAssign(S, F)

	auto getWeak() {
		return WeakPointer!(typeof(this))(this);
	} //getWeak

	@property auto opDispatch(string name)() {
		return mixin("data." ~ name);
	} //opDispatch

	@property auto opDispatch(string name, Args...)(Args args) {
		return mixin("data." ~ name)(args);
	} //opDispatch(args)

	//TODO assignment? do we actually want assignment?

	void doDestroy() {
		data.ref_count -= 1;
		if (data.ref_count == 0) {
			//writefln("[SmartPointer] destroyed object: %s", data.object);
			allocator_.dispose(data.object);
			if (data.weak_count == 0) {
				allocator_.dispose(data);
			}
		}
	} //doDestroy

	~this() {
		doDestroy();
	} //~this

} //SmartPointer

version(unittest) {

	import blindfire.engine.memory : theAllocator;

	struct Test {

	} //Test

}

unittest {

	auto ptr_test = SmartPointer!Test(theAllocator);

}

struct SmartPointer(T, alias FreeFunc) {

	import core.stdc.stdlib : malloc, free;

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	alias Func = FreeFunc;

	private {
		Data!(T)* data;
	}

	@property ref auto get() { return data.object; }
	@disable this(); //no default construction
	alias conv this;

	this(Type thing) {
		data = cast(Data!(T)*)malloc(Data!T.sizeof);
		data.object = thing;
		data.ref_count = 1;
		data.weak_count = 0;
		//writefln("[SmartPointer] acquired object: %s", data.object);
	} //this

	this(ST)(Data!ST* other_data)
		if (is(other_data.Type : Type))
		{
			data = cast(Data!(T)*)other_data;
			data.ref_count += 1;
			//writefln("[SmartPointer] copied object data explicitly: %s", data.object);
		} //this(Data!T*)

	this(S, F)(SmartPointer!(S, F) s)
		if (is(s.Type:Type))
		{
			data = s.data;
			data.ref_count += 1;
			//writefln("[SmartPointer] converted from object: %s", s.data.object);
		} //this(S, F)

	this(this) {
		data = data;
		data.ref_count += 1;
		//writefln("[SmartPointer] copied object: %s", data.object);
	} //this(this)

	auto conv(S, alias F = FreeFunc)() {
		return SmartPointer!(S, F)(this.data);
	} //conv

	void opAssign(S, F)(SmartPointer!(S,F) s)
		if (is(s.Type:Type)) 
	{
		if (data != s.data) {
			doDestroy();
		}
		data = s.data;
		data.ref_count += 1;
		//writefln("[SmartPointer] converted from object: %s", s.data.object);
	} //opAssign(S, F)

	auto getWeak() {
		return WeakPoolPointer!(typeof(this))(this);
	} //getWeak

	@property auto opDispatch(string name)() {
		return mixin("data." ~ name);
	} //opDispatch

	@property auto opDispatch(string name, Args...)(Args args) {
		return mixin("data." ~ name)(args);
	} //opDispatch(args)

	//TODO assignment? do we actually want assignment?

	void doDestroy() {
		data.ref_count -= 1;
		if (data.ref_count == 0) {
			//writefln("[SmartPointer] destroyed object: %s", data.object);
			FreeFunc(data.object);
			if (data.weak_count == 0) {
				free(data);
			}
		}
	} //doDestroy

	~this() {
		doDestroy();
	} //~this

} //SmartPointer

version(unittest) {

}

unittest {

}

struct WeakPointer(SmartPtr) {

	import blindfire.engine.memory : IAllocator, dispose;

	private IAllocator allocator_;
	private typeof(SmartPtr.data) data;
	alias get this;

	private this(ref SmartPtr ptr) {
		writefln("[WeakPointer] created from: %s", ptr);
		allocator_ = ptr.allocator_;
		data = ptr.data;
		data.weak_count += 1;
	} //this

	private this(this) {
		data = data;
		data.weak_count += 1;
		writefln("[WeakPointer] copied: %s", data);
	} //this(this)

	bool isNull() {
		return data.object !is null;
	} //isNull

	SmartPtr get() {
		return SmartPtr(data);
	} //get

	void doDestroy() {
		data.weak_count -= 1;
		if (data.ref_count == 0 && data.weak_count == 0) {
			writefln("[WeakPointer] destroyed container: %s", data);
			allocator_.dispose(data);
		}
	} //doDestroy

	~this() {
		doDestroy();
		writefln("[WeakPointer] destroyed.");
	} //~this

} //WeakPointer

unittest {

}

struct WeakPoolPointer(SmartPtr) {

	private typeof(SmartPtr.data) data;
	alias get this;

	private this(ref SmartPtr ptr) {
		writefln("[WeakPointer] created from: %s", ptr);
		data = ptr.data;
		data.weak_count += 1;
	} //this

	private this(this) {
		data = data;
		data.weak_count += 1;
		writefln("[WeakPointer] copied: %s", data);
	} //this(this)

	bool isNull() {
		return data.object !is null;
	} //isNull

	SmartPtr get() {
		return SmartPtr(data);
	} //get

	void doDestroy() {
		data.weak_count -= 1;
		if (data.ref_count == 0 && data.weak_count == 0) {
			writefln("[WeakPointer] destroyed container: %s", data);
			free(data);
		}
	} //doDestroy

	~this() {
		doDestroy();
		writefln("[WeakPointer] destroyed.");
	} //~this

} //WeakPointer

unittest {

}

struct UniquePointer(T, FreeFunc) {

	private T data;
	@disable this(this); //no copying, only moving!

	this(T in_data) {
		data = in_data;
	} //this

	@property auto opDispatch(string name)() {
		return mixin("data." ~ name);
	} //opDispatch

	@property auto opDispatch(string name, Args...)(Args args) {
		return mixin("data." ~ name)(args);
	} //opDispatch(args)

	~this() {
		FreeFunc(data);
	} //~this

} //UniquePointer

unittest {

}
