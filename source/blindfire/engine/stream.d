module blindfire.engine.stream;

private mixin template StreamImpl() {

	private {
		size_t size;
		size_t offset = 0;
		ubyte* buffer;
	}

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer = data;
		this.size = length;
	} //this

	this(ubyte[] arr) nothrow @nogc {
		this.buffer = arr.ptr;
		this.size = arr.length;
	} //this

	@property const(ubyte*) pointer() nothrow @nogc const {
		return buffer + offset;
	} //pointer

	@property size_t current() nothrow @nogc const {
		return offset;
	} //current

	@property size_t length() nothrow @nogc const {
		return size;
	} //length

	ubyte[] opSlice() nothrow @nogc {
		return buffer[0..offset];
	} //opSlice

}

struct InputStream {

	enum ReadMode {
		Read,
		Peek
	}

	mixin StreamImpl;

	T read(T, ReadMode mode = ReadMode.Read)() nothrow @nogc {

		T obj = *(cast(T*)(buffer[offset..offset+T.sizeof].ptr));

		static if (mode != ReadMode.Peek) {
			offset += T.sizeof;
		}

		return obj;

	} //read

	T[] read(T, ReadMode mode = ReadMode.Read)(uint length) nothrow @nogc {

		auto bytes_len = T.sizeof * length;
		T[] slice = (cast(T*)(buffer[offset..offset].ptr))[0..bytes_len];

		static if(mode != ReadMode.Peek) {
			offset += bytes_len;
		}

		return slice;

	} //read

	void read(Args...)() nothrow @nogc {



	} //read

} //InputStream

struct OutputStream {

	import std.traits : isArray;

	mixin StreamImpl;

	void write(T)(in T obj) nothrow @nogc {
		static if (isArray!(T)) {
			size_t data_size = obj[0].sizeof * obj.length;
			buffer[offset..offset+data_size] = (cast(ubyte*)obj.ptr)[0..data_size];
			offset += data_size;
		} else {
			buffer[offset..offset+obj.sizeof] = (cast(ubyte*)&obj)[0..obj.sizeof];
			offset += obj.sizeof;
		}
	} //write

} //OutputStream
