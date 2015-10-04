module blindfire.engine.pool;

import std.stdio : writefln;

template hasMember(alias obj, string Member) {
	enum hasMember = __traits(hasMember, typeof(obj), Member);
}

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

	mixin PoolCommon!T;
	private Item[] pool;

	@disable this();
	@disable this(this);

	this(size_t initial_size) {

		this.expand(initial_size);

	}

	void expand(size_t extra_space) {

		writefln("[ObjectPool] pool.length: %s, new limit: %s", pool.length, pool.length + extra_space);
		for (size_t i = 0; i < extra_space; ++i) {
			pool ~= Item(new T(Args));
		}

	} //expand

	auto findFreeObject() {

		size_t id = 0;

		if (pool.length < id+1) {
			expand(ExpandSize);
		}

		while (pool[id].active) {
			id += 1;
		}

		return id;

	} //findFreeObject

	auto create(Args...)(Args args) {

		auto id = findFreeObject();
		auto obj = &pool[id];
		reinitialize(obj, args);
		obj.active = true;

		return SmartPointer!(Item*, release)(obj);

	} //create

	static void release(Item* object) {

		writefln("release called for: %s", object);
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

	enum total_runs = 1000;
	auto pool = ObjectPool!(PooledThing, 1000, 0)(32);

	foreach (i; iota(total_runs)) {
		auto v = uniform(int.min, int.max);
		auto thing = pool.create(v);
		assert(thing.var == v, "var in object didn't match v");
	}

}

struct Data(T) {
	alias Type = T;
	T object;
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

struct SmartPointer(T, alias FreeFunc) {

	import core.stdc.stdlib : malloc, free;

	static if (is(T:Object)) {
		alias Type = T;
	} else {
		alias Type = T;
	}

	alias Func = FreeFunc;

	private {
		Data!T* data;
	}

	@property ref T get() { return data.object; }
	@disable this(); //no default construction
	alias conv this;

	this(T thing) {
		data = cast(Data!T*)malloc(Data!T.sizeof);
		data.object = thing;
		data.ref_count = 1;
		data.weak_count = 0;
		writefln("[SmartPointer] acquired object: %s", data.object);
	} //this

	this(ST)(Data!ST* other_data)
		if (is(other_data.Type:Type))
		{
			data = cast(Data!T*)other_data;
			data.ref_count += 1;
			writefln("[SmartPointer] copied object data explicitly: %s", data.object);
		} //this(Data!T*)

	this(S, F)(SmartPointer!(S, F) s)
		if (is(s.Type:Type))
		{
			data = s.data;
			data.ref_count += 1;
			writefln("[SmartPointer] converted from object: %s", s.data.object);
		} //this(S, F)

	this(this) {
		data = data;
		data.ref_count += 1;
		writefln("[SmartPointer] copied object: %s", data.object);
	} //this(this)

	auto conv(S, alias F = FreeFunc)() {
		return SmartPointer!(S, F)(this.data);
	} //conv

	void opAssign(S, F)(SmartPointer!(S,F) s)
		if (is(s.Type:Type)) 
	{
		if (data != s.data) {
			do_destroy();
		}
		data = s.data;
		data.ref_count += 1;
		writefln("[SmartPointer] converted from object: %s", s.data.object);
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

	void do_destroy() {
		data.ref_count -= 1;
		if (data.ref_count == 0) {
			writefln("[SmartPointer] destroyed object: %s", data.object);
			FreeFunc(data.object);
			if (data.weak_count == 0) {
				free(data);
			}
		}
	} //doDestroy

	~this() {
		do_destroy();
	} //~this

} //SmartPointer

version(unittest) {

}

unittest {

}

struct WeakPointer(SmartPtr) {

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

	void do_destroy() {
		data.weak_count -= 1;
		if (data.ref_count == 0 && data.weak_count == 0) {
			writefln("[WeakPointer] destroyed container: %s", data);
			free(data);
		}
	} //doDestroy

	~this() {
		do_destroy();
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