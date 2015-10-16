module blindfire.engine.rpc;

/* rpc, here to simplify implementing networking functionality. */

enum Parameter {

	Primitive,
	Struct

} //Parameter

struct RPCFunc {

	const(char[])[] params_;

} //RPCFunc

struct RPC {

	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.collections : HashMap;

	private {

		IAllocator allocator_;

		HashMap!(string, RPCFunc) functions_;

	}

	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.functions_ = typeof(functions_)(allocator_, 16);

	} //this

	void register(F)(F func) {

	} //register

} //RPC

unittest {

}