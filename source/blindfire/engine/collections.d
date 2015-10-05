module blindfire.engine.collections;

import blindfire.engine.memory : get_size;

/* a set of datastructures which utilize the allocators built for the engine. */
import std.experimental.allocator;
import std.experimental.allocator.common;
import std.experimental.allocator.showcase;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.building_blocks.free_list;

alias AllocFunc = void[] delegate(size_t size) @system;
alias ReAllocFunc = bool delegate(ref void[] block, size_t new_size) @system;
alias DeallocFunc = bool delegate(void[] block) @system;

struct Array(T) {

	private {

		T[] array_;
		size_t capacity_;
		size_t length_;

		IAllocator allocator_;

	}

	this(IAllocator allocator, size_t initial_size) {

		this.allocator_ = allocator;
		this.array_ = allocator.makeArray!T(initial_size);
		this.capacity_ = initial_size;
		this.length_ = 0;

	} //this

	~this() {
		free();
	} //~this

	void free() {
		allocator_.dispose(array_);
	} //free

	@property size_t capacity() const {
		return capacity_;
	} //capacity

	@property size_t length() const {
		return length_;
	} //length

	void add(T item) {

		if (length_ == capacity_) {
			bool success = allocator_.expandArray!T(array_, length_);
			assert(success, "reallocation failed on add!");
		}

		array_[length_++] = item;

	} //add

	ref T get(size_t index) {

		return array_[index];

	} //get

	void remove(size_t index) {

		// [0, 1, 2, 3, 4, 5] -- remove 3, need to shift 4 and 5 one position down
		array_[index..length_-1] = array_[index+1..length_];
		length_--;

	} //remove

} //Array

version(unittest) {

	import std.stdio : writefln;

}

unittest {

	auto free_list = FreeList!(Mallocator, 0, 128)();
	auto array = Array!long(allocatorObject(free_list), 64);

	array.add(25);
	assert(array.get(0) == 25, "didnt' equal 25, wtf?");
	array.add(42);
	array.remove(0);
	assert(array.length == 1, "didn't equal 1, wut?");
	assert(array.get(0) == 42, "didn't equal 42, wat?");

}

/* quadratic probing hashmap implementation */
struct HashMap(K, V) {

	private {

		T[] array_;
		size_t capacity_;

	}

	this(IAllocator allocator, size_t initial_size) {

	} //this

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

struct DHeap(E) {

	this(IAllocator allocator, size_t initial_size) {

	} //this

	~this() {

	} //~this

} //DHeap

struct ScopedBuffer(T) {

	import blindfire.engine.memory : StackAllocator;

	T[] buffer_;
	IAllocator allocator_;

	alias buffer_ this; //careful!

	@disable this(this);

	this(IAllocator allocator, size_t elements) {
		this.buffer_ = allocator.makeArray!T(elements);
		this.allocator_ = allocator;
	} //this

	~this() {
		if (buffer_ != buffer_.init) {
			this.allocator_.deallocate(buffer_);
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
	import std.string : format;

	//StaticArray
	const int size = 10;
	auto arr = StaticArray!(int, size)();
	arr[size-1] = 100;
	assert(arr[size-1] == 100, format("expected arr[%d] to be %d, was %d", size-1, 100, arr[size-1]));

	int[5] int_a = [1, 2, 3, 4, 5];
	arr ~= int_a;
	assert(arr.elements == 5, "expected num of elements to be 5, was: " ~ to!string(arr.elements));

}