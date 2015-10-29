module blindfire.engine.allocator;

import std.experimental.allocator;
import std.traits : hasIndirections;

/**
$(D TrackingAllocator) is an allocator meant to keep track of delegates and pointers
allocated through it, and reassign them when memory happens to move around, is required
for memory safety in the face of reallocations, and possibly defragmentation of memory.
*/
struct TrackingAllocator(ParentAllocator) {

	import blindfire.engine.collections : Array, MultiHashMap;
	import blindfire.engine.meta : hasMember;

	private {

		ParentAllocator parent_;
		MultiHashMap!(void*, void**) registry_;

	}

	enum alignment = ParentAllocator.alignment;

	this(ParentAllocator)(ParentAllocator parent) {

		this.parent_ = parent;
		this.registry_ = typeof(registry_)(allocatorObject(parent_), 16);

	} //this

	this(ParentAllocator)() {

		this.parent_ = ParentAllocator.instance;
		this.registry_ = typeof(registry_)(allocatorObject(parent_), 16);

	} //this

	void[] allocate(size_t bytes) {

		return (cast(shared)parent_).allocate(bytes);

	} //allocate

	static if (hasMember!(ParentAllocator, "alignedAllocate")) {
		void[] alignedAllocate(size_t bytes, uint alignment) {

			return parent_.alignedAllocate(bytes, alignment);

		} //alignedAllocate
	}

	static if (hasMember!(ParentAllocator, "allocateAll")) {
		void[] allocateAll() {

			return parent_.allocateAll();

		} //allocateAll
	}

	static if (hasMember!(ParentAllocator, "expand")) {
		bool expand(ref void[] b, size_t extra_size) {

			return parent_.expand(b, extra_size);

		} //expand
	}

	import std.stdio : writefln;
	bool reallocate(ref void[] b, size_t new_size) {

		auto old_ptr = b.ptr, old_size = b.length;
		auto blk_list = old_ptr in registry_; //check if it exists in the registry

		bool result = (cast(shared)parent_).reallocate(b, new_size);
		auto new_ptr = b.ptr; //new offset in memory for block

		if (result && blk_list && new_ptr != old_ptr) {

			// calculate diff
			ptrdiff_t offset_diff = new_ptr - old_ptr;
			writefln("old: %s, new: %s, offset: %d", old_ptr, new_ptr, offset_diff);

			// set all pointers pointing into block to new location
			foreach (p; *blk_list) {

				// if pointer resides within block being moved
				if (p >= old_ptr && p <= old_ptr + old_size) {

					// since it moved, change where pointee resides as well
					void** moved_ptr = p + offset_diff;
					registry_.put(new_ptr, moved_ptr);
					*moved_ptr += offset_diff;

				} else { //pointer resides outside block, points into it

					// add back pointer since it's location didn't move,
					//  dereference and set new pointing location.
					registry_.put(new_ptr, p);
					*p += offset_diff;

				}

			}

			// get rid of old registry entry
			registry_.remove(old_ptr);

		}

		return true;

	} //reallocate

	static if (hasMember!(ParentAllocator, "alignedReallocate")) {
		bool alignedReallocate(ref void[] b, size_t new_size, uint alignment) {

			return parent_.alignedReallocate(b, new_size, alignment);

		} //alignedReallocate
	}

	static if (hasMember!(ParentAllocator, "owns")) {
		Ternary owns(void[] bytes) const {

			return parent_.owns(bytes);

		} //owns
	}

	void[] resolveInternalPointer(void* ptr) const {
		return null;
	} //resolveInternalPointer

	bool deallocate(void[] bytes) {

		return (cast(shared)parent_).deallocate(bytes);

	} //deallocate

	static if (hasMember!(ParentAllocator, "deallocateAll")) {
		bool deallocateAll() {

			return parent_.deallocateAll();

		} //deallocateAll
	}

	static if (hasMember!(ParentAllocator, "empty")) {
		Ternary empty() const {

			return parent_.empty();

		} //empty
	}

	/* functions specific to TrackingAllocator */
	void registerPointer(void* blk, void** ptr) {

		registry_.put(blk, ptr); /* REGISTAR! */

	} //registerPointer

	void deregisterPointer(void* blk, void** ptr) {

		registry_.remove(blk, ptr); /* DEREGISTAR! */

	} //deregisterPointer

	static TrackingAllocator allocator;

} //TrackingAllocator

unittest {

	import std.stdio : writefln;

	import std.experimental.allocator.mallocator;
	import blindfire.engine.collections : Array;
	import blindfire.engine.pointer : Reference;

	auto allocator = TrackingAllocator!Mallocator(Mallocator.instance);
	auto test_array = Array!int(allocatorObject(&allocator), 1);
	test_array.add(24);

	auto reference = Reference!(typeof(allocator), int)(&allocator, cast(void*)test_array.ptr, test_array.ptr);
	writefln("ptr: %s, value: %d", reference.get(), *reference.get());

	test_array.add(72);
	test_array.add(45);
	test_array.add(65);
	test_array.add(92);
	test_array.add(112);

	writefln("ptr: %s, value: %d", reference.get(), *reference.get());
	assert(*reference.get() == 24);

}