module smidig.memory.pointer;

import std.experimental.allocator.common : Ternary;
import smidig.memory;

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

	import smidig.memory : IAllocator, make, dispose;

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

	import smidig.memory.common : theAllocator;

	struct Test {

	} //Test

}

@name("SmartPointer (allocator) 1: (unimplemented")
unittest {

	auto ptr_test = SmartPointer!Test(theAllocator);
	assert(0);

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

	import smidig.memory : IAllocator, dispose;

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

@name("WeakPointer 1 (unimplemented)")
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

	@disable this();
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

@name("UniquePointer 1 (unimplemented)")
unittest {
	assert(0);
}

/**
 * Equivalent to the C++ make_shared, returns a smart pointer created
 * with the given allocator and the carried object is instantiated with the args.
*/
auto make_shared(T, Args...)(IAllocator allocator, Args args) {

	return SmartPointer(allocator, args);

} //make_shared

/**
 * Equivalent to the C++ make_unique, returns a smart pointer created
 * with the given allocator and the carried object is instantiated with the args.
*/
auto make_unique(T, Args...)(IAllocator allocator, Args args) {

} //make_unique
