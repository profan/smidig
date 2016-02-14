module smidig.rpc;

import tested : name;

/**
 * Structure used to register functions which are meant to able to be called
 * over the network, as well as "call" functions on other hosts, by serializing
 * the function name passed, as well as the arguments.
*/
struct RPC {

	import smidig.collections : HashMap;
	import smidig.memory : IAllocator, Region, Mallocator, makeArray;
	import smidig.stream : InputStream, OutputStream;

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

	@disable this();
	@disable this(this);

	this(IAllocator allocator) {

		assert(allocator, "allocator was null?");

		this.allocator_ = allocator;
		this.region_allocator_ = typeof(region_allocator_)(RegionSize);
		this.functions_ = typeof(functions_)(allocator_, 16);
		this.byte_buffer_ = region_allocator_.makeArray!ubyte(RegionSize);
		this.out_stream_ = OutputStream(byte_buffer_);

	} //this

	/**
	 * Given the function name and arguments, serializes the arguments
	 * and writes them to the structure's attached output stream.
	*/
	void call(Args...)(string name, Args args) {

		out_stream_.write(name);

		foreach (param; args) {
			out_stream_.write(param);
		}

	} //call

	/**
	 * Registers a function with the $(D RPC) struct.
	*/
	ref typeof(this) register(string name, WrapperFunction func) {

		functions_[name] = func;

		return this;

	} //register

	/**
	 * Reads from a given byte buffer, parsing the name and then calling the
	 * corresponding function with the rest of the stream contents.
	*/
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

	import smidig.meta : Identifier;

	string doReads(ref string[] args) {

		auto reads = appender!string();

		foreach (i, param; ParameterTypeTuple!F) {
			reads ~= q{auto arg%d = stream.read!(%s)();}.format(i, param.stringof);
			args ~= q{arg%d}.format(i);
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

@name("RPC 1: test calling wrapped function")
unittest {

	bool equal(T)(T[] a1, T[] a2) {

		foreach (i, ref e; a1) {
			if (e != a2[i]) return false;
		}

		return true;

	} //equal

	import std.stdio : writefln;
	import smidig.memory : theAllocator;
	import smidig.stream : InputStream, OutputStream;

	uint input_test;
	int[] data_test;

	void hello_world(uint input, int[] data) {
		input_test = input;
		data_test = data;
	}

	mixin(generateWrapper!(hello_world));

	auto rpc = RPC(theAllocator);
	rpc.register("hello_world", &hello_world_wrapper);

	int[3] data = [1, 2, 3];
	rpc.call("hello_world", 1234, data);

	// reads from the stream, reads function name first which uses hashmap to call wrapper func.
	assert(0);

	/*
	rpc.onPull(rpc.out_stream_[]);
	assert(input_test == 1234);
	assert(equal(data_test, data));
	*/

}
