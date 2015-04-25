module blindfire.engine.stream;

struct InputStream {

	enum ReadMode {
		Read,
		Peek
	}

	private {
		size_t size;
		size_t offset = 0;
		ubyte* buffer;
	}

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer = data;
		this.size = length;
	}

	@property const(ubyte*) pointer() nothrow @nogc const {
		return buffer + offset;
	}

	@property size_t current() const {
		return offset;
	}

	@property size_t length() const {
		return size;
	}

	T read(T, ReadMode mode = ReadMode.Read)() nothrow @nogc {
		T obj = *(cast(T*)(buffer[offset..offset+T.sizeof].ptr));
		static if (mode != ReadMode.Peek) {
			offset += T.sizeof;
		}
		return obj;
	}

}

struct OutputStream {

	size_t size;
	size_t current = 0;
	ubyte* buffer;

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer = data;
		this.size = length;
	}

	void write(T)() nothrow @nogc {
		
	}

}
