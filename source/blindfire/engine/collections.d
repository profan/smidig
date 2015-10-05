module blindfire.engine.collections;

/* a set of datastructures which utilize the allocators built for the engine. */
import blindfire.engine.memory;

struct Array(T) {

	private {

		T* array_;

	}

	this(size_t initial_size) {

	} //this

	~this() {

	} //~this

	void add(T item) {

	} //add

	void get(size_t index) {

		return array_[index];

	} //get

	void remove(T item) {

	} //remove

} //Array

struct DynamicArray {

	this (size_t initial_size) {

	}

	~this() {
		//free
	}

} //DynamicArray

struct HashMap(Allocator, K, V) {

	this (size_t initial_size, Allocator alloc) {

	}

	~this() {
		//free
	}

	ref V get(in K key) {

	} //get

	void put(in K key, V value) {

	} //put

} //HashMap

struct LinkedList {

} //LinkedList

struct DHeap {

} //DHeap

struct ScopedBuffer(Allocator, T) {

	T[] buffer;
	Allocator* allocator;

	alias buffer this;

	@disable this(this);

	this(StackAllocator* allocator, size_t elements) {
		this.buffer = (cast(T*)allocator.alloc(elements * T.sizeof))[0..elements];
	} //this

	~this() {
		if (buffer != buffer.init) {
			this.allocator.dealloc(buffer);
		}
	} //~this

} //ScopedBuffer

struct StaticArray(T, size_t size) {

	private size_t elements = 0;
	private T[size] array;

	this(T[] items) {
		foreach(e; items) {
			array[elements++] = e;
		}
	} //this

	@property size_t length() const {
		return elements;
	} //length

	@property void length(size_t new_length) {
		elements = new_length;
	} //length

	@property size_t capacity() const {
		return array.length;
	} //capacity

	size_t opDollar(int dim)() const {
		static assert(dim == 0);
		return elements;
	} //opDollar

	void opOpAssign(string op: "~")(T item) {
		array[elements++] = item;
	} //opOpAssign

	void opOpAssign(string op: "~")(in T[] items) {
		foreach(e; items) {
			array[elements++] = e;
		}
	} //opOpAssign

	ref T opIndex(size_t i) {
		return array[i];
	} //opIndex

	//whole thing
	T[] opSlice() {
		return array[0..elements];
	} //opSlice

	T[] opSlice(size_t h, size_t t) {
		return array[h..t];
	} //opSlice

	ref T opIndexAssign(T value, size_t i) {
		return array[i] = value;
	} //opIndexAssign

	void opAssign(StaticArray!(T, size) other) { //TODO should it clean up the contents it has in it first?
		this.array = other.array;
		this.elements = other.elements;
	} //opAssign

} //StaticArray

unittest {

	import std.conv : to;

	//StaticArray
	const int size = 10;
	auto arr = StaticArray!(int, size)();
	arr[size-1] = 100;
	assert(arr[size-1] == 100, format("expected arr[%d] to be %d, was %d", size-1, 100, arr[size-1]));

	int[5] int_a = [1, 2, 3, 4, 5];
	arr ~= int_a;
	assert(arr.elements == 5, "expected num of elements to be 5, was: " ~ to!string(arr.elements));

}