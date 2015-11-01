module blindfire.engine.memory.pointer;

import std.experimental.allocator.common : Ternary;

import blindfire.engine.memory;

/* will hold moving allocator aware pointers, and a registry for them. */

struct Delegate(T) {

	import std.traits : isDelegate;

	static assert(isDelegate!T);

	private {

		IAllocator allocator_;
		T delegate_;

	}

	this(IAllocator allocator, T dele) {

		this.allocator_ = allocator;
		this.delegate_ = dele;

		auto success = this.allocator_.registerPointer(&delegate_.ptr);
		assert(success == Ternary.yes, "allocator doesn't support registerPointer?");

	} //this

	~this() {

		auto success = this.allocator_.deregisterPointer(&delegate_.ptr);
		assert(success == Ternary.yes, "allocator doesn't support deregisterPointer?");

	} //~this

	alias delegate_ this;

} //Delegate

unittest {

}

struct Reference(T) {

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	private {

		IAllocator allocator_;
		Type pointer_;

	}

	this(IAllocator allocator, Type pointer) {

		this.pointer_ = pointer;
		this.allocator_ = allocator;
		auto success = this.allocator_.registerPointer(cast(void**)&pointer_);
		assert(success == Ternary.yes, "allocator doesn't support registerPointer?");

	} //this

	~this() {

		auto success = this.allocator_.deregisterPointer(cast(void**)&pointer_);
		assert(success == Ternary.yes, "allocator doesn't support deregisterPointer?");

	} //~this

	Type get() {
		return pointer_;
	} //get

} //Reference

unittest {

}
