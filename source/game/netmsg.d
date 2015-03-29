module blindfire.netmsg;

/* used in the header for net messages to the game, create creates enties, destroy kills them, update modifies */
enum UpdateType {
	CREATE,
	DESTROY,
	UPDATE
}

struct NetMessage {
	
} //NetMessage

struct InputStream {

	size_t size;
	size_t current = 0;
	ubyte[]* buffer;
	this(ubyte[]* data) {
		this.buffer = data;
		this.size = data.length;
	}

	T read(T)() @nogc {
		T obj = *(cast(T*)*(buffer[current..T.sizeof].ptr));	
		current += T.sizeof;
		return obj;
	}

}

struct OutputStream {

	size_t size;
	size_t current = 0;
	ubyte[]* buffer;
	this(ubyte[]* data) {
		this.buffer = data;
		this.size = data.length;
	}

	void write(T)() @nogc {
		
	}

}
