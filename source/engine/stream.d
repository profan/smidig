module blindfire.engine.stream;

struct InputStream {

	size_t size;
	size_t current = 0;
	ubyte* buffer;

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer = data;
		this.size = length;
	}

	T read(T)() nothrow @nogc {
		T obj = *(cast(T*)(buffer[current..current+T.sizeof].ptr));
		current += T.sizeof;
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
