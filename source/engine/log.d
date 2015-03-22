module sundownstandoff.log;

import core.stdc.stdio : printf;
import std.stdio : writefln;

void logInfo(T...)(string prefix, string format, T args) {
	writefln("[%s] " ~ format, prefix, args);
}
