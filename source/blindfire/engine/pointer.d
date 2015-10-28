module blindfire.engine.pointer;

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

struct Pointer(T) {

	static if (is(T == class)) {
		alias Type = T;
	} else {
		alias Type = T*;
	}

	private {

		Type pointer_;

	}

	this(Type pointer) {
		this.pointer_ = pointer;
	} //this

} //Pointer