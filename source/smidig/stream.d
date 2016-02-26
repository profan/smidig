module smidig.stream;

private mixin template StreamImpl() {

	import std.traits : isArray;

	private {
		size_t size_;
		size_t offset_ = 0;
		ubyte* buffer_;
	}

	this(ubyte* data, size_t length) nothrow @nogc {
		this.buffer_ = data;
		this.size_ = length;
	} //this

	this(in ubyte[] arr) nothrow @nogc {
		this.buffer_ = cast(ubyte*)arr.ptr;
		this.size_ = arr.length;
	} //this

	@property const(ubyte*) pointer() nothrow @nogc const {
		return buffer_ + offset_;
	} //pointer

	@property size_t current() nothrow @nogc const {
		return offset_;
	} //current

	@property size_t length() nothrow @nogc const {
		return size_;
	} //length

	@property bool eof() nothrow @nogc const {
		assert(offset_ <= size_, "offset_ was greater than size_, ran past.");
		return offset_ == size_;
	} //eof

	const(ubyte[]) opSlice() nothrow @nogc const {
		return buffer_[0..offset_];
	} //opSlice

} //StreamImpl

struct InputStream {

	enum ReadMode {
		Read,
		Peek
	} //ReadMode

	mixin StreamImpl;

	@property size_t remaining() const {
		return size_ - offset_;
	} //remaining

	T read(T, ReadMode mode = ReadMode.Read)() nothrow @nogc {

		T obj = *(cast(T*)(buffer_[offset_..offset_+T.sizeof].ptr));

		static if (mode != ReadMode.Peek) {
			offset_ += T.sizeof;
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
		T[] slice = (cast(T*)(buffer_[offset_..offset_].ptr))[0..length];

		static if (mode != ReadMode.Peek) {
			offset_ += bytes_len;
		}

		return slice;

	} //read

} //InputStream

struct OutputStream {

	mixin StreamImpl;

	void write(T)(in T obj) nothrow @nogc {
		static if (isArray!(T)) {
			size_t data_size_ = obj[0].sizeof * obj.length;
			write(obj.length); //write array length to stream
			buffer_[offset_..offset_+data_size_] = (cast(ubyte*)obj.ptr)[0..data_size_];
			offset_ += data_size_;
		} else {
			buffer_[offset_..offset_+obj.sizeof] = (cast(ubyte*)&obj)[0..obj.sizeof];
			offset_ += obj.sizeof;
		}
	} //write

} //OutputStream
