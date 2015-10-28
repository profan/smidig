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

	private {

		ParentAllocator parent_;
		MultiHashMap!(void*, void*) registry_;

	}

	this(ParentAllocator)(ParentAllocator parent) {

		this.parent_ = parent;
		this.registry_ = typeof(registry_)(allocatorObject(parent_), 16);

	} //this

	void[] allocate(size_t bytes) {
		return null;
	} //allocate

	void[] alignedAllocate(size_t bytes, uint alignment) {
		return null;
	} //alignedAllocate

	void[] allocateAll() {
		return null;
	} //allocateAll

	bool expand(ref void[] b, size_t extra_size) {
		return false;
	} //expand

	bool reallocate(ref void[] b, size_t new_size) {
		return false;
	} //reallocate

	bool alignedReallocate(ref void[] b, size_t new_size, uint alignment) {
		return false;
	} //alignedReallocate

	Ternary owns(void[] bytes) const {
		return Ternary.no;
	} //owns

	void[] resolveInternalPointer(void* ptr) const {
		return null;
	} //resolveInternalPointer

	bool deallocate(void[] bytes) {
		return false;
	} //deallocate

	bool deallocateAll() {
		return false;
	} //deallocateAll

	Ternary empty() const {
		return Ternary.yes;
	} //empty

	/* functions specific to TrackingAllocator */
	void registerPointer(void[] blk, void* ptr) {

		registry_.put(blk.ptr, ptr); /* REGISTAR! */

	} //registerPointer

	void deregisterPointer(void[] blk, void* ptr) {

		registry_.remove(blk.ptr, ptr); /* DEREGISTAR! */

	} //deregisterPointer

} //TrackingAllocator

unittest {

	import std.experimental.allocator.mallocator;

	auto allocator = TrackingAllocator!Mallocator(Mallocator.instance);

}