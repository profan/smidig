module blindfire.engine.pointer;

import blindfire.engine.allocator : TrackingAllocator;

/* will hold moving allocator aware pointers, and a registry for them. */

struct Delegate(T) {

	private {

		T delegate_;

	}

	this(T dele) {
		this.delegate_ = dele;
	} //this

	alias delegate_ this;

} //Delegate

unittest {

}

struct Reference(Allocator, T) {

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	private {

		Allocator* allocator_;
		void* parent_block_;
		Type pointer_;

	}

	this(Allocator* allocator, void* parent_block, Type pointer) {
		this.pointer_ = pointer;
		this.allocator_ = allocator;
		this.parent_block_ = parent_block;
		this.allocator_.registerPointer(parent_block_, cast(void**)&pointer_);
		this.allocator_.registerPointer(parent_block_, &parent_block_);
	} //this

	~this() {
		this.allocator_.deregisterPointer(parent_block_, &parent_block_);
		this.allocator_.deregisterPointer(parent_block_, cast(void**)&pointer_);
	} //~this

	Type get() {
		return pointer_;
	}

} //Reference

unittest {

}