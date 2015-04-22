module blindfire.engine.memory;

import core.memory : GC;
import core.stdc.stdlib : malloc, free;

import std.stdio : writefln;
import std.conv : emplace;

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

struct LinearAllocator {

	bool composed;

	void* buffer;
	void* current;
	size_t total_size;
	size_t allocated_size = 0;

	size_t pointer_count = 0;
	Instance[100] allocated_pointers = void;

	this(size_t size) {

		this.composed = false;
		//since we're allocating the memory here, we're not part of another allocator's space.

		this.total_size = size;
		this.buffer = malloc(total_size);

		//lets make this GC aware while we're there
		GC.addRange(buffer, total_size);

		//set pointer to top
		this.current = buffer;

	}

	this(size_t size, LinearAllocator* master) {

		this.composed = true;
		this.total_size = size;
		this.buffer = master.alloc(total_size, uint.sizeof);
		this.current = buffer;

	}

	@disable this(this);

	~this() {

		for (size_t i = 0; i < pointer_count; ++i) {
			allocated_pointers[i].destroy_object();
			destroy(allocated_pointers[i]);
		}

		writefln("[LinearAllocator] freed %d bytes, %d bytes allocated in %d elements.", total_size, allocated_size, pointer_count);

		if (!composed) {
			GC.removeRange(buffer);
			free(buffer);
		}

	}

	void* alloc(size_t size, size_t alignment) {

		auto align_offset = get_aligned(current, alignment);
	
		allocated_size += align_offset;
		current += align_offset;

		void* allocated_start = current;
		allocated_size += size;
		current += size;

		return allocated_start;

	}

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

	}

	auto alloc(T, Args...)(Args args) {

		auto element = alloc_item!(T, Args)(args);
		static if (is(T == struct) || is(T == class)) {
			allocated_pointers[pointer_count++] = alloc_item!(MemoryObject!T)(element);
		}

		return element;

	}

} //LinearAllocator

unittest {

}

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

	void* buffer;
	void* current;
	size_t total_size;
	size_t allocated_size;
	
	size_t pointer_count = 0;
	Instance[100] allocated_pointers = void;

	this(size_t size) {

		this.total_size = size;
		this.allocated_size = 0;

		this.buffer = malloc(total_size);
		this.current = buffer;

		GC.addRange(buffer, total_size);

	}

	@disable this(this);

	~this() nothrow {
		
	}

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

	}

	void* alloc(bool header = false)(size_t bytes) {

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

		return block;

	}

	auto alloc(T, Args...)(Args args) {

		auto element = alloc_item!(T, Args)(args);
		auto header = alloc_item!(Header)(get_size!T());

		return element;

	}

	void dealloc(size_t size) {

		allocated_size -= size;
		current -= size;

	}

	void dealloc() {

		auto header_size = get_size!Header();
		auto header = *cast(Header*)(current - header_size);

		allocated_size -= (header_size - header.size);
		current -= (header_size - header.size);

	}

} //StackAllocator

unittest {

}

//returns an aligned offset in bytes from current to allocate from.
private ptrdiff_t get_aligned(T = void)(void* current, size_t alignment = T.alignof) {

	ptrdiff_t diff = alignment - (cast(ptrdiff_t)current & (alignment-1));
	return (diff == T.alignof) ? 0 : diff;

}

//returns size of type in memory
size_t get_size(T)() {

	static if (is(T == class)) {
		return __traits(classInstanceSize, T);
	} else {
		return T.sizeof;
	}

}
