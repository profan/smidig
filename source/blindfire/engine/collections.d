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

struct ScopedBuffer(T) {

	T[] buffer;
	StackAllocator* allocator;

	alias buffer this;

	@disable this(this);

	this(StackAllocator* allocator, size_t elements) {
		this.buffer = (cast(T*)allocator.alloc(elements * T.sizeof))[0..elements];
	} //this

	~this() {
		this.allocator.dealloc(buffer.length * T.sizeof);
	} //~this

} //ScopedBuffer
