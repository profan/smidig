module blindfire.engine.collections;

/* a set of datastructures which utilize the allocators built for the engine. */
import blindfire.engine.memory;

struct DynamicArray {

	this (size_t initial_size) {

	}

	~this() {
		//free
	}

} //DynamicArray

struct HashMap(Allocator) {

	this (size_t initial_size, Allocator alloc) {

	}

	~this() {
		//free
	}

} //HashMap

struct LinkedList {

} //LinkedList

struct DHeap {

} //DHeap
