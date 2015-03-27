module sundownstandoff.serialize;

import sundownstandoff.net : NetVar;

static template SerializeMember() {
	
}

byte[T.sizeof] serialize(T)(T* object) {
	byte[T.sizeof] b;
	return b;
}
