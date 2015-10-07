module blindfire.engine.memory;

import core.memory : GC;
import core.stdc.stdlib : malloc, free;

import std.stdio : writefln;
import std.conv : emplace;

public import std.experimental.allocator : allocatorObject, IAllocator, theAllocator, make, makeArray, dispose;
public import std.experimental.allocator.building_blocks.region : Region;
public import std.experimental.allocator.mallocator : Mallocator;

void memmove(T)(T[] src, T[] target) {

	import core.stdc.string : memmove;
	memmove(target.ptr, src.ptr, src.length * T.sizeof);
	
}

private interface Instance {
	void destroy_object();
}

private class MemoryObject(T) : Instance {

	static if (is(T == struct)) {
		T* object;
		this(T* ptr) {
			this.object = ptr;
		}
	} else static if (is(T == class)) {
		T object;
		this(T obj_ref) {
			this.object = obj_ref;
		}
	}

	void destroy_object() {
		static if (is(T == struct)) {
			destroy(*object);
		} else static if(is(T == class)) {
			destroy(object);
		}
	}

}

private mixin template AllocatorCommon() {

	void* buffer;
	void* current;
	size_t total_size;
	size_t allocated_size;
	immutable char[] name;

	auto alloc_item(T, Args...)(Args args) {

		size_t item_size = get_size!(T)();
		auto item_alignment = get_aligned!(T)(current);

		//align item
		allocated_size += item_alignment;
		current += item_alignment;

		auto memory = buffer[allocated_size .. allocated_size+item_size];
		allocated_size += item_size;
		current += item_size;

		return emplace!(T)(memory, args);

	} //alloc_item

	@property size_t remaining_size() const nothrow @nogc {

		assert(allocated_size <= total_size);
		auto remaining = total_size - allocated_size;

		return remaining;

	} //remaining_size

} //AllocatorCommon

private mixin template AllocatorInvariant() {

	invariant {

		assert(current >= buffer, "current buffer pos should always be greater than block start");
		assert(allocated_size <= ((current - buffer) + total_size), "allocated size should always be less or equal to size of block.");

	}

} //AllocatorInvariant

struct LinearAllocator {

	bool composed;
	size_t pointer_count = 0;
	Instance[100] allocated_pointers = void;

	@disable this(this);

	this(size_t size, string name) nothrow {

		this.composed = false;
		//since we're allocating the memory here, we're not part of another allocator's space.

		this.total_size = size;
		this.buffer = malloc(total_size);

		//lets make this GC aware while we're there
		GC.addRange(buffer, total_size);

		//set pointer to top
		this.current = buffer;
		this.name = name;

	} //this

	this(size_t size, string name, LinearAllocator* master) nothrow @nogc {

		this.composed = true;
		this.total_size = size;
		this.buffer = master.alloc(total_size, uint.sizeof);
		this.current = buffer;
		this.name = name;

	} //this

	~this() {

		for (size_t i = 0; i < pointer_count; ++i) {
			allocated_pointers[i].destroy_object();
			destroy(allocated_pointers[i]);
		}

		writefln("[LinearAllocator:%s] freed %d bytes, %d bytes allocated in %d elements.", name, total_size, allocated_size, pointer_count);

		if (!composed) {
			GC.removeRange(buffer);
			free(buffer);
		}

	} //~this

	void* alloc(size_t size, size_t alignment) nothrow @nogc {

		auto align_offset = get_aligned(current, alignment);

		assert(allocated_size + (align_offset + size) < total_size);
	
		allocated_size += align_offset;
		current += align_offset;

		void* allocated_start = current;
		allocated_size += size;
		current += size;

		return allocated_start;

	} //alloc

	auto alloc(T, Args...)(Args args) {

		auto element = alloc_item!(T, Args)(args);
		static if (is(T == struct) || is(T == class)) {
			allocated_pointers[pointer_count++] = alloc_item!(MemoryObject!T)(element);
		}

		return element;

	} //alloc

	void reset() nothrow {

		allocated_size = 0;
		current = buffer;

	} //reset

	mixin AllocatorInvariant;
	mixin AllocatorCommon;

} //LinearAllocator

unittest {

} //LinearAllocator Tests

struct StackAllocator {

	struct Handle(T) {
		MemoryObject!T obj;
	}

	struct Header {

		this(size_t bytes) {
			this.size = bytes;
		}

		size_t size;

	}

	size_t pointer_count = 0;
	Instance[100] allocated_pointers = void; //FIXME get rid of this limitation, this is... very bad :D

	@disable this(this);

	this(size_t size, string name) nothrow {

		this.total_size = size;
		this.allocated_size = 0;

		this.buffer = malloc(total_size);
		this.current = buffer;

		GC.addRange(buffer, total_size);
		this.name = name;

	}

	~this() {

		if (total_size > 0) {
			writefln("[StackAllocator:%s] freed %d bytes, %d bytes allocated.", name, total_size, allocated_size);
		}

	}


	void[] alloc(bool header = false)(size_t bytes) {

		assert (allocated_size + bytes <= total_size, "tried to allocate TOO DAMN MUCH");

		auto item_alignment = get_aligned!(void*)(current);
		allocated_size += item_alignment;
		current += item_alignment;

		auto block = current;
		allocated_size += bytes;
		current += bytes;

		static if (header) {
			auto header = alloc_item!(Header)(bytes);
		}

		return block[0..bytes];

	}

	auto alloc(T, Args...)(Args args) {

		auto element = alloc_item!(T, Args)(args);
		auto header = alloc_item!(Header)(get_size!T());

		return element;

	}

	void dealloc(AT)(ref in AT[] arr) nothrow @nogc {

		dealloc(arr.length * typeof(arr).sizeof);
		
	}

	void dealloc(size_t size) nothrow @nogc {

		allocated_size -= size;
		current -= size;

	}

	void dealloc() nothrow @nogc {

		auto header_size = get_size!Header();
		auto header = *cast(Header*)(current - header_size);

		allocated_size -= (header_size - header.size);
		current -= (header_size - header.size);

	}


	mixin AllocatorInvariant;
	mixin AllocatorCommon;

} //StackAllocator

unittest {

	import std.random : uniform;

	enum total_alloc_size = 65536;
	auto sa = StackAllocator(total_alloc_size, "Test");
	size_t min_size = 3, max_size = 2048;

	size_t total_allocated = 0;
	while (total_allocated < total_alloc_size*0.75) {

		size_t alloc_size;
		do { alloc_size = uniform(min_size, max_size); } while (cast(long)alloc_size > cast(long)(sa.remaining_size - alloc_size));

		auto allocated_bytes = sa.alloc(alloc_size);
		total_allocated += allocated_bytes.length;

	}

	sa.dealloc(total_allocated);

} //StackAllocator Tests

//returns an aligned offset in bytes from current to allocate from.
private ptrdiff_t get_aligned(T = void)(void* current, size_t alignment = T.alignof) nothrow @nogc pure {

	import std.traits : classInstanceAlignment;
	import std.conv : to;

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
