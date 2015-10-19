module blindfire.engine.collections;

/* a set of datastructures which utilize the allocators built for the engine. */
import std.experimental.allocator : allocatorObject, IAllocator, theAllocator, make, makeArray, expandArray, shrinkArray, dispose;
import std.experimental.allocator.building_blocks.free_list : FreeList;
import std.experimental.allocator.mallocator : Mallocator;

struct Array(T) {

	import std.algorithm : move;

	private {

		IAllocator allocator_;

		T[] array_;
		size_t capacity_;
		size_t length_;

	}

	//@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size) {

		this.allocator_ = allocator;
		this.array_ = allocator_.makeArray!T(initial_size);
		this.capacity_ = initial_size;
		this.length_ = 0;

	} //this

	~this() {
		if (allocator_ !is null) {
			this.free();
		}
	} //~this

	void free() {
		this.allocator_.dispose(array_);
	} //free

	void clear() nothrow @nogc { //note, does not run destructors!
		this.length_ = 0;
	} //clear

	@property size_t capacity() const nothrow @nogc {
		return capacity_;
	} //capacity

	@property size_t length() const nothrow @nogc {
		return length_;
	} //length

	@property size_t length(size_t new_length) nothrow @nogc { //no-op if length is too large
		if (new_length <= capacity_) {
			length_ = new_length;
		}
		return length_;
	} //length

	@property T[] data() nothrow @nogc {
		return array_;
	} //data

	@property const(T*) ptr() const nothrow {
		return array_.ptr;
	} //ptr

	@property T* ptr() nothrow {
		return array_.ptr;
	} //ptr

	int opApply(int delegate(ref size_t i, ref T) dg) {

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

	size_t opDollar(int dim)() const nothrow {
		static assert(dim == 0); //TODO remember what this does..
		return length_;
	} //opDollar

	const(T[]) opSlice() const nothrow {
		return array_[0..length_];
	} //opSlice

	T[] opSlice() nothrow {
		return array_[0..length_];
	} //opSlice

	T[] opSlice(size_t h, size_t t) nothrow {
		return array_[h..t];
	} //opSlice

	void opOpAssign(string op: "~")(T item) {
		this.add(item);
	} //opOpAssign

	void opOpAssign(string op: "~")(in T[] items) {
		foreach (ref item; items) {
			this.add(item);
		}
	} //opOpAssign

	void opIndexAssign(T value, size_t index) {
		array_[index] = move(value);
	} //opIndexAssign

	static if (isCopyable!T) {
		void opIndexAssign(ref T value, size_t index) nothrow {
			array_[index] = value;
		} //opIndexAssign
	}

	ref T opIndex(size_t index) @nogc nothrow {
		return array_[index];
	} //opIndex

	void reserve(size_t requested_size) {

		if (capacity_ < requested_size) {
			this.expand(requested_size - capacity_);
		}

	} //reserve

	void expand(size_t extra_size) {

		bool success = allocator_.expandArray!T(array_, extra_size);
		capacity_ += extra_size;

		assert(success, "failed to expand array!");

	} //expand

	void add(T item) {

		if (length_ == capacity_) {
			this.expand(length_);
		}

		array_[length_++] = move(item);

	} //add

	static if (isCopyable!T) {
		void add(ref T item) {

			if (length_ == capacity_) {
				this.expand(length_);
			}

			array_[length_++] = item;

		} //add
	}

	ref T get(size_t index) {
		return array_[index];
	} //get

	void remove(size_t index) {

		import std.string : format;
		import std.algorithm : copy, moveAll;
		import blindfire.engine.memory : memmove;

		assert(index < length_,
			   format("removal index was greater or equal to length of array, cap/len was: %d:%d", capacity_, length_));

		// [0, 1, 2, 3, 4, 5] -- remove 3, need to shift 4 and 5 one position down
		memmove(array_[index+1..length_], array_[index..length_-1]);
		length_--;

	} //remove

	void remove(ref T thing) {

		foreach(ref i, ref e; this) {
			if (e == thing) {
				this.remove(i);
				return;
			}
		}

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

unittest {

	auto array = Array!int(theAllocator, 0);
	array.reserve(32);

	assert(array.capacity == 32);

}

struct FixedArray(T) {

} //FixedArray

/* array type which never moves its contents in memory */
/* - composed of arrays in fixed sizes. */
struct SegmentedArray(T) {

} //SegmentedArray

unittest {

}

size_t toHash(string str) @trusted nothrow {
	return typeid(str).getHash(&str) % 31;
} //toHash for string

size_t toHash(int k) @nogc @safe pure nothrow {
	return k % 31;
} //toHash

template isCopyable(T) {
	enum isCopyable = __traits(compiles, function T(T t) { return t; });
} //isCopyable

/* quadratic probing hashmap implementation */
/* - currently linear probing though. */
struct HashMap(K, V) {

	import std.algorithm : move;

	// when used_capacity_ / capacity_ > threshold, expand & rehash!
	enum LOAD_FACTOR_THRESHOLD = 0.75;

	enum State {
		Free,
		Data
	} //State

	struct Entry {
		K key;
		V value;
		State state = State.Free;
		alias value this;
	} //Entry

	private {

		Entry[] array_;
		size_t capacity_;
		size_t used_capacity_;

		IAllocator allocator_;

	}

	@disable this(this);

	static if (isCopyable!K) { /* define only if key type is copyable too */
		@property Array!K keys() {

			auto arr = Array!K(allocator_, used_capacity_);

			foreach (ref k, ref v; this) {
				arr.add(k);
			}

			return arr;

		} //keys
	}

	static if (isCopyable!V) { /* it only makes sense to define this if value type is copyable */
		@property Array!V values() {

			auto arr = Array!V(allocator_, used_capacity_);

			foreach (ref k, ref v; this) {
				arr.add(v);
			}

			return arr;

		} //values
	}

	@property size_t length() const {
		return capacity_;
	} //length

	this(IAllocator allocator, size_t initial_size) {

		this.allocator_ = allocator;
		this.array_ = allocator.makeArray!Entry(initial_size);
		this.capacity_ = initial_size;

	} //this

	~this() {
		if (allocator_ !is null) {
			this.free();
		}
	} //~this

	void free() {
		this.allocator_.dispose(array_);
	} //free

	/* move other instance into self */
	void move_from(ref typeof(this) other) {

		this.free();
		this.array_ = move(other.array_);
		this.capacity_ = move(other.capacity_);
		this.used_capacity_ = move(other.used_capacity_);
		this.allocator_ = move(other.allocator_);

		other.allocator_ = null;
		assert(other.allocator_ is null);

	} //move_from

	V* opBinaryRight(string op = "in")(in K key) nothrow {

		bool found = false;
		auto index = findIndex(key, found);
		V* ptr = null;

		if (found) {
			ptr = &array_[index].value;
		}

		return ptr;

	} //opBinaryRight

	int opApply(int delegate(ref K, ref V) dg) {

		int result = 0;

		foreach (ref i, ref e; array_) {
			if (e.state == State.Data) {
				result = dg(e.key, e.value);
			}
			if (result) break;
		}

		return result;

	} //opApply

	int opApply(int delegate(ref V) dg) {

		int result = 0;

		foreach (ref e; array_) {
			if (e.state == State.Data) {
				result = dg(e.value);
			}
			if (result) break;
		}

		return result;

	} //opApply

	void opIndexAssign(V value, K key) {
		put(key, move(value));
	} //opIndexAssign

	ref V opIndex(in K key) {
		return get(key);
	} //opIndex

	void rehash() {

		auto temp_map = HashMap!(K, V)(allocator_, capacity_ * 2);

		foreach (ref k, ref v; this) {
			temp_map[k] = move(v);
		}

		this.move_from(temp_map);

	} //rehash

	ref V get(in K key) nothrow {
		return get_(key);
	} //get

	private size_t findIndex(in K key, out bool found) nothrow {

		auto index = key.toHash() % capacity_;
		uint searched_elements = 0;
		size_t fallback_index = -1;
		found = true;

		while (array_[index].key != key || array_[index].state == State.Free) {

			if (array_[index].state == State.Free) {
				fallback_index = index;
			}

			if (array_[index].key == key && array_[index].state == State.Data) {
				found = true;
				return index; //found!
			}

			searched_elements++;
			index = (index + 1) % capacity_;

			if (searched_elements == capacity_) {
				found = false;
				return fallback_index;
			}

		}

		return index;

	} //findIndex

	private ref V get_(in K key) nothrow {

		bool found = false;
		auto index = findIndex(key, found);
		return array_[index].value;

	} //get

	void put(ref K key, V value) {

		import std.algorithm : move;

		auto index = key.toHash() % capacity_;
		auto default_value = K.init;

		if ((cast(float)used_capacity_ / cast(float)capacity_) > LOAD_FACTOR_THRESHOLD) {
			this.rehash();
		}

		while (array_[index].key != key && array_[index].state != State.Free) {
			index = (index + 1) % capacity_;
		}

		if (array_[index].state == State.Free) { //new key/value pair!
			used_capacity_++;
		}

		array_[index] = Entry(key, move(value), State.Data);

	} //put

	bool remove(K key) {

		auto index = key.toHash() % capacity_;
		uint searched_elements = 0;

		while (array_[index].key != key) {

			if (searched_elements == capacity_) {
				return false;
			}

			searched_elements++;
			index = (index + 1) % capacity_;

		}
		
		array_[index].key = K.init;
		array_[index].value = V.init;
		array_[index].state = State.Free;
		used_capacity_--;

		return true;
		
	} //remove

	void clear() {

		foreach (i, ref e; array_[]) {
			e = Entry.init;
		}

		used_capacity_ = 0;

	} //clear

} //HashMap

version(unittest) {

	struct HashThing {

		string content;

		size_t toHash() const @safe pure nothrow {
			return content.hashOf() * 31;
		} //toHash

		bool opEquals(const typeof(this) s) @safe pure nothrow {
			return content == s.content;
		} //opEquals

		bool opEquals(ref const typeof(this) s) @safe pure nothrow {
			return content == s.content;
		} //opEquals

		bool opEquals(const typeof(this) s) const @safe pure nothrow {
			return content == s.content;
		} //opEquals

	} //HashThing

}

unittest {

	auto hash_map = HashMap!(HashThing, uint)(theAllocator, 32);

	auto thing = HashThing("hello");

	hash_map[thing] = 255;
	assert(hash_map[thing] == 255);
	assert(thing in hash_map);

	hash_map[thing] = 128;
	assert(hash_map[thing] == 128);
	assert(thing in hash_map);

}

unittest {

	import std.string : format;

	auto hash_map = HashMap!(string, uint)(theAllocator, 16);
	enum str = "yes";

	{

		hash_map[str] = 128;
		assert(hash_map[str] == 128);
		auto p = str in hash_map;
		assert(p && *p == 128);

	}

	{

		hash_map[str] = 324;
		assert(hash_map[str] == 324);
		bool success = hash_map.remove(str);
		assert(success, "failed to remove str?");
		assert(hash_map[str] != 324, "entry was still 324?");
		hash_map[str] = 500;
		auto p = str in hash_map;
		assert(p && *p == 500);

	}

	foreach (ref key, ref value; hash_map) {
		assert(key == str && value == 500, format("key or value didn't match, %s : %s", key, value));
	}

}

unittest { //test expansion

	enum initial_size = 4, rounds = 128;
	auto hash_map = HashMap!(uint, bool)(theAllocator, 4);

	foreach (i; 0..rounds) {
		hash_map[i] = true;
	}

	foreach (i; 0..rounds) {
		assert(hash_map[i]);
	}

}

struct SparseArray(T) {

	struct Entry {
		size_t index;
	} //Entry

	@disable this();
	@disable this(this);

} //SparseArray

struct LinkedList(T) {

	struct Node {
		Node* next;
		T data;
	} //Node
	
	private {

		Node* head_;

		IAllocator allocator_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {
		this.allocator_ = allocator;
	}  //this

	~this() {

		auto cur = head_;
		while (cur != null) {
			auto last = cur;
			cur = cur.next;
			allocator_.dispose(last);
		}

	} //~this

	void add(T item) {

		this.push(&head_, item);

	} //add

	void push(Node** node, ref T data) {

		auto new_node = allocator_.make!Node(null, data);
		new_node.next = *node;

		*node = new_node;

	} //push

	void poll() {

		if (head_) {
			auto last_head = head_;
			head_ = head_.next;
			allocator_.dispose(last_head);
		}

	} //poll

	T* head() {
		return &head_.data;
	} //first

} //LinkedList

version(unittest) {

}

unittest {

	auto list = LinkedList!int(theAllocator);

	list.add(35);
	assert(*list.head() == 35);

}

struct Stack(T) {

	private LinkedList!T list_;

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {
		this.list_ = LinkedList!T(allocator);
	} //this

	void push(T item) {
		list_.add(item);
	} //push

	T* peek() {
		return list_.head();
	} //peek

	T pop() {
		auto item = list_.head();
		if (!item) {
			return T.init;
		} else {
			list_.poll();
			return *item;
		}
	} //pop

} //Stack

version(unittest) {

}

unittest {

	auto stack = Stack!int(theAllocator);
	stack.push(25);

	assert(*stack.peek() == 25);

}

struct Queue(T) {

	private LinkedList!T list_;

} //Queue

unittest {

}

struct DHeap(int N, T) {

	import std.algorithm : move;

	private {

		Array!T array_;
		IAllocator allocator_;
		size_t size_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator, size_t initial_size) {
		this.allocator_ = allocator;
		this.array_ = typeof(array_)(allocator_, initial_size);
	} //this

	uint nth_child(uint n, uint i) {

		return (N * i) + n;

	} //nth_child

	size_t parent(size_t i) {

		return (i-1) / N;

	} //parent

	void percolate_up(size_t cur) {

		if (cur == 0) return;

		auto p = parent(cur);
		if (array_[cur] > array_[p] || array_[cur] == array_[p]) {
			return;
		} else {
			swap(cur, p);
			percolate_up(p);
		}

	} //percolate_up

	void swap(size_t source, size_t target) {

		import blindfire.engine.memory : memswap;
		memswap(&array_[source], &array_[target]);

	} //swap

	void insert(T thing) {

		array_[size_] = thing;
		percolate_up(size_);
		size_++;

	} //insert

	void min_heapify(size_t cur) {

		size_t[N] children;
		foreach (i, ref c; children) {
			c = nth_child(i+1, cur);
		}

		auto capacity = size_;
		foreach (c; children) { 
			if (c > capacity) { return; }
		}

		//check if it's actually bigger
		foreach (c; children) {
			if (array_[cur] > array_[c]) {

				size_t smallest_child = size_t.max;

				foreach (inner_c; children) {
					if (smallest_child == size_t.max || array_[smallest_child] > array_[inner_c]) {
						smallest_child = inner_c;
					}
				}

				swap(cur, smallest_child);
				min_heapify(smallest_child);
				return;

			}
		}

	} //min_heapify

	T delete_min() {

		size_--;
		swap(0, size_); //swap root and last (we want root)
		auto min = &array_[size_];
		auto min_data = move(*min);
		*min = T.max; //value should define a max, so it can be put out of the way in the heap
		min_heapify(0);

		return min_data;

	} //delete_min

} //DHeap

version (unittest) {

	struct CompThing {

		int thing = int.max;

		int opCmp(ref CompThing other) {

			if (thing > other.thing) return 1;
			if (thing < other.thing) return -1;

			return 0;

		} //opCmp

		@property static CompThing max() {

			return CompThing(int.max);

		} //max

	} //CompThing

} 

unittest {

	import std.string : format;
	import std.stdio : writefln;
	import std.algorithm : filter;

	auto heap = DHeap!(3, CompThing)(theAllocator, 24);

	heap.insert(CompThing(10));
	heap.insert(CompThing(32));
	heap.insert(CompThing(52));
	heap.insert(CompThing(12));
	heap.insert(CompThing(65));
	heap.insert(CompThing(11));
	heap.insert(CompThing(7));

	auto checks = [7, 10, 11, 12, 32, 52, 65];

	foreach (c; checks) {

		auto min_val = heap.delete_min();
		auto expected = CompThing(c);
		assert(min_val == expected, format("expected: %s, got: %s, \n tree was: %s", expected, min_val, heap.array_.array_));

	}
}

struct MatrixGraph(T) {

} //Graph

struct HashSet(T) {

	IAllocator allocator_;
	HashMap!(T, bool) hashmap_;

	this(IAllocator allocator, size_t initial_size) {
		this.allocator_ = allocator;
		this.hashmap_ = typeof(hashmap_)(allocator_, initial_size);
	} //this

	bool add(T item) {

		auto exists = item in hashmap_;

		if (!exists) {
			hashmap_[item] = true;
		}

		return !exists;

	} //add

	bool exists(T item) {

		auto ptr = item in hashmap_;
		return !!ptr;

	} //exists

	bool remove(T item) {

		return hashmap_.remove(item);

	} //remove

} //HashSet

unittest {

	auto set = HashSet!int(theAllocator, 32);

	set.add(24);
	assert(set.exists(24));

}

struct QuadTree {

	struct Quadrant {

		Quadrant*[4] quads;

	} //Quadrant

	IAllocator allocator_;
	Array!Quadrant quadrants_;

	this(IAllocator allocator, size_t initial_size) {

	} //this

	~this() {

	} //~this

} //QuadTree

unittest {

}

/* our immutable string type, it has a length and a null terminator. */
/* - null terminator to make interop with c stuff easier. */
struct String {

	private {

		IAllocator allocator_;
		Array!char array_ = void; //TODO look at this, is this right?

	}

	@property size_t length() const nothrow @nogc {
		return array_.length;
	} //length

	@disable this(this);

	this(ref String str, in char[] input) {
		
		auto input_length = input.length;
		if(input[$-1] == '\0') {
			input_length -= 1;
		}

		this.allocator_ = theAllocator;
		this.array_ = typeof(array_)(allocator_, str.length + input_length + 1);
		this.array_.length = str.length + input_length;

		this.array_[][0..str.length] = str[];
		this.array_[][str.length..str.length+input_length] = input[0..input_length];
		this.array_[$] = '\0'; //HELLA NULL TERMINATION SON

	} //this

	this(in char[] input) {

		auto input_length = input.length;

		if (input_length != 0) {
			if(input[$-1] == '\0') {
				input_length -= 1;
			}
		}

		this.allocator_ = theAllocator;
		this.array_ = typeof(array_)(allocator_, input_length + 1);
		this.array_.length = input_length;

		this.array_[][0..input_length] = input[0..input_length];
		this.array_[$] = '\0'; //HELLA NULL TERMINATION SON

	} //this

	size_t toHash() @safe const nothrow {
		return d_str().toHash();
	} //toHash

	const(char[]) opSlice() nothrow {
		return array_[0..length];
	} //opSlice

	const(char[]) opSlice(size_t h, size_t t) nothrow {
		return array_[h..t];
	} //opSlice

	bool opEquals(in char[] other) {

		foreach (i, ref c; array_) {
			if (array_[i] != other[i]) {
				return false;
			}
		}

		return true;

	} //opEquals

	bool opEquals(ref String other) {

		if (other is this) {
			return true;
		}

		return this.opEquals(other.array_[]);

	} //opEquals

	String opBinary(string op: "~")(ref String str) {
		return String(this, str.d_str);
	} //opBinary

	String opBinary(string op: "~")(in char[] chars) {
		return String(this, chars);
	} //opBinary

	const(char*) c_str() const nothrow @nogc {
		return array_.ptr;
	} //c_str

	string d_str() const nothrow @nogc @trusted {
		return cast(immutable(char)[])array_[];
	} //d_str

} //String

unittest {

	auto str = String("yes");
	auto new_string = str ~ "other_thing";

	assert(new_string == "yes" ~ "other_thing");
	assert(new_string.d_str == "yes" ~ "other_thing");

}

/* mutable char buffer */
struct StringBuffer {

	private {

		Array!char array_;

	}

	this(size_t initial_size) {

		this.array_ = typeof(array_)(theAllocator, initial_size);

	} //this

	void opOpAssign(string op: "~")(in char[] str) {

		array_ ~= str;

		if (str[$-1] != '\0') {
			array_ ~= '\0';
		}

		array_.length(array_.length-1);

	} //opOpAssign

	void opOpAssign(string op: "~")(ref String str) {

		array_ ~= str[];

	} ///opOpAssign

	const(char*) c_str() const nothrow @nogc {
		return array_.ptr;
	} //c_str

} //StringBuffer

unittest {

	import core.stdc.stdio : printf;

	auto strbuf = StringBuffer(32);
	strbuf ~= "yes \n";

	printf("strbuf: %s", strbuf.c_str());

}

/* tree used for fuzzy string searching */
struct BKTree {

	/* hey look, we don't need to write it ourselves :U~ */
	import std.algorithm.comparison : levenshteinDistance;
	import std.typecons : Nullable;
	import std.algorithm : move;

	struct Node {

		enum prealloc_size = 5;

		String word;
		Array!Node children;

		this(ref BKTree tree, ref String str) {
			this.children = typeof(children)(tree.allocator_, prealloc_size);
			this.word = move(str);
		}

	} //Node

	IAllocator allocator_;
	Node root_;

	this(IAllocator allocator) {
		this.allocator_ = allocator;
	} //this

	~this() {

	} //~this

	void insert(String string) {

	} //insert

	string query(in char[] str_view, int max_distance) {
		return root_.word.d_str;
	} //query

} //BKTree

unittest {

}

struct ScopedBuffer(T) {

	private IAllocator allocator_;

	T[] buffer_;
	alias buffer_ this; //careful!

	@disable this(this);

	this(IAllocator allocator, size_t elements) {
		this.buffer_ = allocator.makeArray!T(elements);
		this.allocator_ = allocator;
	} //this

	~this() {
		if (allocator_ !is null) {
			this.allocator_.dispose(buffer_);
		}
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
	import std.string : format;
	import std.random : uniform;

	enum runs = 500, size = 128;

	auto buf = ScopedBuffer!int(theAllocator, size);

	foreach (i; iota(runs)) {
		auto index = uniform(0, size-1);
		buf[index] = i;
		assert(buf[index] == i, format("buf[index] was %d, expected %d", buf[index], i));
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

	@property T* ptr() {
		return array.ptr;
	} //ptr

	static if (is(T == char)) {
		void scan_to_null() {

			auto index = 0;
			while (index < array.length-1 && array[index] != '\0') {
				index++;
			}

			if (index < array.length-1 && array[index] == '\0') {
				elements = index+1;
			}

		} //scan_to_null
	}

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
	assert(arr.elements == 5, format("expected num of elements to be 5, was: %s", arr.elements));
	assert(arr[$-1] == 5, format("expected last element to be 5, was: %s", arr[$]));

}