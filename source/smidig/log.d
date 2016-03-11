module smidig.log;

/* output for all loggers, tls loggers sync towards this one. */
shared LoggerOutput g_logger;

/* tls logger, is what normally is used to write. */
Logger!4096 tls_logger;

struct LoggerOutput {

} //LoggerOutput

struct Logger(size_t BufferSize) {

	import smidig.util : cformat;

	private {

		char[BufferSize] buffer_;
		size_t current_ = 0;

	}

	@nogc
	nothrow
	void write
		(string file = __FILE__,
		 size_t line = __LINE__,
		 string mod = __MODULE__,
		 string func = __FUNCTION__)
		(in char[] what) {

	   	// can't write with this buffer size in one go, divide
		if (what.length > buffer_.length) {

		}

		// can't write until we flush the buffer to our output
		if (current + what.length > buffer_.length) {

		}

		auto buf = buffer_[current..current+what.length];
		buf[] = what[]; // copy the shit

	} //write

	void writef(Args...)(in char[] format, Args args) {

	} //writef

	void writeln(Args...)(in char[] what) {

	} //writeln

	void writefln(Args...)(in char[] format, Args args) {

	} //writefln

} //Logger
