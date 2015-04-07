module blindfire.memory;

import std.stdio : writefln;
import core.stdc.stdlib : malloc, free;
import std.conv : emplace;
import core.memory : GC;

interface Instance {
	void destroy_object();
}

class MemoryObject(T) : Instance {

	T* object;
	this(T* ptr) {
		this.object = ptr;
	}

	void destroy_object() {
		destroy(*object);
	}

}

struct StackAllocator {

	void* buffer;
	size_t total_size;
	size_t allocated_size = 0;

	size_t pointer_count = 0;
	Instance[100] allocated_pointers = void;

	this(size_t stack_size) {

		this.total_size = stack_size;
		this.buffer = malloc(total_size);

		//lets make this GC aware while we're there
		GC.addRange(buffer, total_size);

	}

	~this() {

		GC.removeRange(buffer);
		for (size_t i = 0; i < pointer_count; ++i) {
			allocated_pointers[i].destroy_object();
			destroy(allocated_pointers[i]);
		}

		free(buffer);
		writefln("[StackAllocator] freed %d bytes, %d bytes allocated in %d elements.", total_size, allocated_size, pointer_count);

	}

	auto allocate(T, Args...)(Args args) {

		size_t item_size = get_size!T();
		auto memory = buffer[allocated_size .. allocated_size+item_size];
		allocated_size += item_size;

		auto element = emplace!(T, Args)(memory, args);

		size_t wrapper_size = get_size!(MemoryObject!T);
		auto wrapper_memory = buffer[allocated_size .. allocated_size+wrapper_size];
		allocated_size += wrapper_size;

		static if (is(T == class)) {
			allocated_pointers[pointer_count++] = &element;
		} else if (is(T == struct)) {
			allocated_pointers[pointer_count++] = emplace!(MemoryObject!T)(wrapper_memory, element);
		}

		return element;

	}

}

size_t get_size(T)() {

	static if (is(T == class)) {
		return __traits(classInstanceSize, T);
	} else if (is(T == struct)) {
		return T.sizeof;
	}

}
