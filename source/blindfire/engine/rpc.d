module blindfire.engine.rpc;

import std.stdio : writefln;

/* rpc, here to simplify implementing networking functionality. */

enum Parameter {

	Primitive,
	Struct

} //Parameter

struct RPCFunc {

	const(char[])[] params_;

} //RPCFunc

struct RPC {

	enum RegionSize = 1024 * 8; //8 kilobytes yes

	import blindfire.engine.collections : HashMap;
	import blindfire.engine.memory : IAllocator, Region, Mallocator, makeArray;
	import blindfire.engine.stream : InputStream, OutputStream;

	private {

		IAllocator allocator_;
		Region!Mallocator region_allocator_;

		HashMap!(string, RPCFunc) functions_;

		/* holds temp data */
		ubyte[] byte_buffer_;
		OutputStream out_stream_;

	}

	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.region_allocator_ = typeof(region_allocator_)(RegionSize);
		this.functions_ = typeof(functions_)(allocator_, 16);
		this.byte_buffer_ = region_allocator_.makeArray!ubyte(1024 * 8);
		this.out_stream_ = OutputStream(byte_buffer_);

	} //this

	void call(Args...)(string name, Args args) {

		out_stream_.write(name.length);
		out_stream_.write(name);

		foreach (param; args) {
			out_stream_.write(param);
		}

	} //call

	void register(F)(F func) {

	} //register

	void on_pull(ref InputStream stream) {

		auto name_len = stream.read!uint();
		auto name = stream.read!char(name_len);
		writefln("name: %s", name);

	} //on_pull

	/* push written byte data to where it is to be used, or something? */
	void do_push() {

	} //do_push

} //RPC

unittest {

	import std.stdio : writefln;
	import blindfire.engine.memory : theAllocator;
	import blindfire.engine.stream : InputStream, OutputStream;

	void hello_world(int input) {
		writefln("input: %d", input);
	}

	auto rpc = RPC(theAllocator);
	rpc.call("hello_world", 1234);
	writefln("byte buffer: %s", rpc.out_stream_[]);

	auto in_stream = InputStream(rpc.out_stream_[]);
	rpc.on_pull(in_stream);

}