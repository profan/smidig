module blindfire.engine.rpc;

struct RPC {

	/* rpc, here to simplify implementing networking functionality. */

	import blindfire.engine.collections : HashMap;
	import blindfire.engine.memory : IAllocator, Region, Mallocator, makeArray;
	import blindfire.engine.stream : InputStream, OutputStream;

	alias WrapperFunction = void delegate(ref InputStream stream);

	enum RegionSize = 1024 * 8; //8 kilobytes yes

	private {

		IAllocator allocator_;
		Region!Mallocator region_allocator_;

		HashMap!(string, WrapperFunction) functions_;

		/* holds temp data */
		ubyte[] byte_buffer_;
		OutputStream out_stream_;

	}

	@disable this(this);

	this(IAllocator allocator) {

		this.allocator_ = allocator;
		this.region_allocator_ = typeof(region_allocator_)(RegionSize);
		this.functions_ = typeof(functions_)(allocator_, 16);
		this.byte_buffer_ = region_allocator_.makeArray!ubyte(RegionSize);
		this.out_stream_ = OutputStream(byte_buffer_);

	} //this

	void call(Args...)(string name, Args args) {

		out_stream_.write(name);

		foreach (param; args) {
			out_stream_.write(param);
		}

	} //call

	ref typeof(this) register(string name, WrapperFunction func) {

		functions_[name] = func;

		return this;

	} //register

	void onPull(in ubyte[] data) {

		auto stream = InputStream(data);

		while (!stream.eof) {

			auto name = stream.read!string();
			functions_[name](stream);

		}

	} //onPull

	/* push written byte data to where it is to be used, or something? */
	void doPush(ref OutputStream stream) {

	} //doPush

} //RPC

string generateWrapper(alias F)() {

	import std.string : format;
	import std.traits : ParameterTypeTuple;
	import std.array : appender;

	import blindfire.engine.meta : Identifier;

	string doReads(ref string[] args) {

		auto reads = appender!string();

		foreach (i, param; ParameterTypeTuple!F) {
			reads ~= q{auto arg%d = stream.read!(%s)();}.format(i, param.stringof);
			args ~= format("arg%d", i);
		}

		return reads.data;

	} //do_reads

	string doArgs(string[] args) {

		auto in_str = appender!string();

		foreach (i, arg; args) {
			in_str ~= arg;
			if (i != args.length-1) in_str ~= ",";
		}

		return in_str.data;

	} //do_args

	string doCall(string[] args) {

		return q{%s(%s);}.format(Identifier!F, doArgs(args));

	} //do_call

	string[] func_args = [];
	string str = q{void %s_wrapper(ref InputStream stream) { %s %s }}
		.format(Identifier!F, doReads(func_args), doCall(func_args));

	return str;

} //generateWrapper

string generateWrappers(Funcs...)() {

	import std.array : appender;

	auto str = appender!string();

	foreach (fn; Funcs) {
		str ~= generateWrapper!fn();
	}

	return str.data;

} //generateWrappers

unittest {

	import std.stdio : writefln;
	import blindfire.engine.memory : theAllocator;
	import blindfire.engine.stream : InputStream, OutputStream;

	void hello_world(uint input, int[] data) {
		writefln("input: %d %s", input, data);
	}

	void goodbye(uint val, bool no) {
		writefln("goodbye - val : %d, no : %s", val, no);
	}

	// generates wrapper functions which look like:
	// void hello_world_wrapper(ref InputStream stream) {
	//     auto arg0 = stream.read!uint();
	//     hello_world(arg0);
	// }

	mixin(generateWrappers!(hello_world, goodbye));

	auto rpc = RPC(theAllocator);
	rpc.register("hello_world", &hello_world_wrapper);
	rpc.register("goodbye", &goodbye_wrapper);

	int[3] data = [1, 2, 3];
	rpc.call("hello_world", 1234, data);
	rpc.call("goodbye", 324, false);

	// reads from the stream, reads function name first which uses hashmap to call wrapper func.
	rpc.onPull(rpc.out_stream_[]);

}