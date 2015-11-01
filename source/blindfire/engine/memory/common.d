module blindfire.engine.memory.common;

public import std.experimental.allocator : allocatorObject, IAllocator, processAllocator, theAllocator, make, makeArray, dispose;
public import std.experimental.allocator.building_blocks.region : Region;
public import std.experimental.allocator.mallocator : Mallocator;

void memmove(T)(auto ref T[] src, auto ref T[] target) {

	import core.stdc.string : memmove;
	memmove(target.ptr, src.ptr, src.length * T.sizeof);
	src = src.init;

} //memmove

unittest {

	import std.algorithm : equal;
	int[4] expected = [124, 3624, 6234, 52324];

	int[4] mem_src = expected;
	int[4] mem_trg;

	memmove(mem_src[], mem_trg[]);

	assert(equal(mem_trg[], expected[]));

}

void memmove(T)(T* src, T* target) {

	import core.stdc.string : memmove;
	memmove(target, src, T.sizeof);

} //memmove

unittest {

}

void memmove(T)(IAllocator allocator, T[] src, T[] target) {

	/* notify allocator that memory has moved */
	allocator.notifyMove(src, target.ptr, T.sizeof * src.length);
	memmove(src, target);

} //memmove

unittest {

	import blindfire.engine.pointer : Reference;
	import blindfire.engine.allocator : TrackingAllocator;

	auto alloc = TrackingAllocator!Mallocator();
	auto alloc_obj = allocatorObject(&alloc);

	int item1 = 10;
	int item2;

	auto reference = Reference!int(alloc_obj, &item1);
	memmove(alloc_obj,
			(cast(int*)item1)[0..int.sizeof],
			(cast(int*)item2)[0..int.sizeof]);

}

void memswap(T)(T* src, T* target) {

	import core.stdc.string : memcpy;

	T tmp = void;
	memcpy(&tmp, target, T.sizeof);
	memmove(src, target);
	memmove(&tmp, src);

} //memswap

//returns an aligned offset in bytes from current to allocate from.
private ptrdiff_t get_aligned(T = void)(void* current, size_t alignment = T.alignof) nothrow @nogc pure {

	import std.traits : classInstanceAlignment;

	static if (is(T == class)) {
		enum class_alignment = classInstanceAlignment!T;
		alignment = class_alignment;
	}

	ptrdiff_t diff = alignment - (cast(ptrdiff_t)current & (alignment-1));
	return (diff == T.alignof) ? 0 : diff;

} //get_aligned

//returns size of type in memory
size_t get_size(T)() nothrow @nogc pure {

	static if (is(T == class)) {
		return __traits(classInstanceSize, T);
	} else {
		return T.sizeof;
	}

} //get_size