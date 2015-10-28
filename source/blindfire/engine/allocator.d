module blindfire.engine.allocator;

import std.experimental.allocator;

/**
$(D TrackingAllocator) is an allocator meant to keep track of delegates and pointers
allocated through it, and reassign them when memory happens to move around, is required
for memory safety in the face of reallocations, and possibly defragmentation of memory.
*/
struct TrackingAllocator {

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

} //TrackingAllocator

unittest {

}