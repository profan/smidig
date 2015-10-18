module blindfire.engine.net;

struct NetVar(T) {

	alias variable this;
	bool changed = false;
	
	union {
		T variable;
		ubyte[T.sizeof] bytes;
	}

	this(T var) {
		this.variable = var;
	}

	T opUnary(string op)() if (s == "++" || s == "--") {
		changed = true;
		mixin("return " ~ op ~ " variable;");
	}

	void opAssign(T rhs) {
		changed = true;
		variable = rhs;
	}

	void opOpAssign(string op)(T rhs) {
		changed = true;
		mixin("variable " ~ op ~ "= rhs;");
	}

	T opBinary(string op)(T rhs) {
		mixin("return variable " ~ op ~ " rhs;");
	}

} //NetVar

void initialize_enet() {

	import core.stdc.stdio : printf;
	import derelict.enet.enet;

	if (auto err = enet_initialize() != 0) {

		printf("[Net] An error occured on initialization: %d", err);

	}

} //initialize_enet

struct NetworkManager {

	import derelict.enet.enet;

	private {

		ENetAddress address;
		ENetHost* host;

	}

	@property bool is_host() { return true; } //is_host

	@disable this();
	@disable this(this);

	this(bool is_client) {

	} //this

	~this() {

	} //~this

	void initialize() {

	} //initialize

	void poll() {

	} //poll

} //NetworkManager

struct NetworkServer {

} //NetworkServer

struct NetworkClient {

} //NetworkClient