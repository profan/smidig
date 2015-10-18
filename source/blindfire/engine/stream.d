module blindfire.engine.stream;

private mixin template StreamImpl() {

	import std.traits : isArray;

	private {
		size_t size;
		size_t offset = 0;
		ubyte* buffer;
	}

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer = data;
		this.size = length;
	} //this

	this(in ubyte[] arr) nothrow @nogc {
		this.buffer = cast(ubyte*)arr.ptr;
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

	@property bool eof() nothrow @nogc const {
		assert(offset <= size, "offset was greater than size, ran past.");
		return offset == size;
	} //eof

	const(ubyte[]) opSlice() nothrow @nogc const {
		return buffer[0..offset];
	} //opSlice

} //StreamImpl

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

	T[] read(T : T[], ReadMode mode = ReadMode.Read)() nothrow @nogc {

		auto arr_len = read!(uint, mode)();
		return read!(T, mode)(arr_len);

	} //read

	T[] readArray(T, ReadMode mode = ReadMode.Read)() nothrow @nogc {

		auto arr_len = read!(uint, mode)();
		return read!(T, mode)(arr_len);

	} //readArray

	T[] read(T, ReadMode mode = ReadMode.Read)(uint length) nothrow @nogc {

		auto bytes_len = T.sizeof * length;
		T[] slice = (cast(T*)(buffer[offset..offset].ptr))[0..length];

		static if (mode != ReadMode.Peek) {
			offset += bytes_len;
		}

		return slice;

	} //read

} //InputStream

struct OutputStream {

	mixin StreamImpl;

	void write(T)(in T obj) nothrow @nogc {
		static if (isArray!(T)) {
			uint data_size = obj[0].sizeof * obj.length;
			write(obj.length); //write array length to stream
			buffer[offset..offset+data_size] = (cast(ubyte*)obj.ptr)[0..data_size];
			offset += data_size;
		} else {
			buffer[offset..offset+obj.sizeof] = (cast(ubyte*)&obj)[0..obj.sizeof];
			offset += obj.sizeof;
		}
	} //write

} //OutputStream
