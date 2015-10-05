module blindfire.engine.collections;

import blindfire.engine.memory : get_size;

/* a set of datastructures which utilize the allocators built for the engine. */
import std.experimental.allocator;
import std.experimental.allocator.common;
import std.experimental.allocator.showcase;
import std.experimental.allocator.mallocator : Mallocator;
import std.experimental.allocator.building_blocks.free_list;

struct Array(T) {

	private {

		T[] array_;
		size_t capacity_;
		size_t length_;

		IAllocator allocator_;

	}

	@disable this();
	@disable this(this);

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

	int opApply(int delegate(ref uint i, ref T) dg) {

		int result = 0;

		foreach (i, ref e; this[]) {
			result = dg(i, e);
			if (result) break;
		}

		return result;

	} //opApply

	int opApply(int delegate(ref T) dg) {

		int result = 0;

		foreach (ref e; this[]) {
			result = dg(e);
			if (result) break;
		}

		return result;

	} //opApply

	@property size_t capacity() const {
		return capacity_;
	} //capacity

	@property size_t length() const {
		return length_;
	} //length

	size_t opDollar(int dim)() const {
		static assert(dim == 0);
		return length_;
	} //opDollar

	T[] opSlice() {
		return array_[0..length_];
	} //opSlice

	T[] opSlice(size_t h, size_t t) {
		return array_[h..t];
	} //opSlice

	ref T opIndexAssign(T value, size_t index) {
		return array_[index] = value;
	} //opIndexAssign

	ref T opIndex(size_t index) {
		return array_[index];
	} //opIndex

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

unittest {

	auto array = Array!long(theAllocator, 4);

	auto to_find = [1, 2, 3, 4];

	foreach (e; to_find) {
		array.add(e);
	}

	foreach (i, e; array) {
		assert(to_find[i] == e);
	}

}

/* quadratic probing hashmap implementation */
struct HashMap(K, V) {

	private {

		V[] array_;
		size_t capacity_;

		IAllocator allocator_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size) {

		this.allocator_ = allocator;
		this.array_ = allocator.makeArray!V(initial_size);

	} //this

	~this() {
		//free
	}

	ref V opIndexAssign(V value, K key) {
		return put(key, value);
	} //opIndexAssign

	ref V opIndex(in K key) {
		return get(key);
	} //opIndex

	ref V get(in K key) {
		return array_[key.hashCode() % capacity_];
	} //get

	void put(in K key, V value) {
		array_[key.hashCode() % capacity_] = value;
	} //put

} //HashMap

version(unittest) {

}

unittest {

}

struct LinkedList(T) {

	struct Node {
		Node* prev;
		Node* next;
		T data;
	} //Node
	
	private {

		Node* first;
		Node* last;

		IAllocator allocator;

	}

	@disable this();
	@disable this(this);

	~this() {

		for (auto n = first; n != null; n = n.next) {

		}

	} //~this

	void add(T item) {

	} //add

	ref T get() {

	} //get

	ref T get(size_t index) {

	} //get

	void remove() {

	} //remove

	void remove(T item) {

	} //remove

} //LinkedList

version(unittest) {

}

unittest {

}

struct DHeap(E) {

	this(IAllocator allocator, size_t initial_size) {

	} //this

	~this() {

	} //~this

} //DHeap

version (unittest) {

} 

unittest {

}

struct ScopedBuffer(T) {

	private IAllocator allocator_;

	T[] buffer_;
	alias buffer_ this; //careful!

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t elements) {
		this.buffer_ = allocator.makeArray!T(elements);
		this.allocator_ = allocator;
	} //this

	~this() {
		this.allocator_.dispose(buffer_);
	} //~this

} //ScopedBuffer

version (unittest) {

	struct DestructTest {

		int* var;
		int target;

		this(int* v, int t) {
			this.var = v;
			this.target = t;
		}

		~this() {
			if (var != typeof(var).init) {
				*var = target;
			}
		}

	}

}

unittest {

	import std.range : iota;
	import std.random : uniform;

	enum runs = 500, size = 128;

	auto buf = ScopedBuffer!int(theAllocator, size);

	foreach (i; iota(runs)) {
		auto index = uniform(0, size-1);
		buf[index] = i;
		assert(buf[index] == i, "buf[index] wasn't i");
	}

}

unittest {

	int testing_var = 256;
	enum target = int.max;

	{
		auto buf = ScopedBuffer!DestructTest(theAllocator, 4);
		buf[2] = DestructTest(&testing_var, target);
	}

	assert(testing_var == target, "destructor didn't fire for DestructTest?");

}

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