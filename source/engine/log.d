module blindfire.log;

import core.stdc.stdio : printf;
import std.stdio : writefln;
import std.conv : to;

struct Logger(string prefix, T) {
	
	T* state;
	this(T* var) {
		this.state = var;
	}

	void log(T...)(lazy string format, T args) {
		writefln("[%s] (%s) " ~ format, prefix, to!string(*state), args);
	}

}

