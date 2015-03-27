module sundownstandoff.serialize;

import profan.collections : StaticArray;
import sundownstandoff.net : NetVar;
import std.bitmanip;

enum networked = "networked";

template isAttribute(alias curAttr, alias Attr) {
	enum isAttribute = is(typeof(curAttr) == typeof(Attr));
}

template hasAttribute(T, alias Member, alias Attribute, Attributes...) {

	static if (Attributes.length > 0 && isAttribute!(Attribute, Attributes[0])) {

		enum hasAttribute = true;

	} else static if (Attributes.length > 0) {

		enum hasAttribute = hasAttribute!(T, Member, Attribute, Attributes[1 .. $]);

	} else {

		enum hasAttribute = false;

	}

}

template getAttributes(T, alias Member) {
	enum getAttributes = __traits(getAttributes, __traits(getMember, T, Member));
}

template Identifier(alias Sym) {
	enum Identifier = __traits(identifier, Sym);
}

template Symbol(alias T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

template Symbol(T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

template isPOD(T) {
	enum isPOD = __traits(isPOD, T);
}

template NetVarToSym(T, alias Member) {
	enum NetVarToSym = Symbol!(T, Member).variable;
}

template ForEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum ForEachMember =
			Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ members[0] ~ ".bytes;"
				~ ForEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum ForEachMember = ForEachMember!(T, data, members[1 .. $]);

	} else {

		enum ForEachMember = "";

	}

}

template WriteHeader(T, alias data, alias object, alias id) {
	enum WriteHeader =
		Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ "identifier_bytes;" ~
		Identifier!(data) ~ " ~= " ~ "(cast(ubyte*)&" ~ Identifier!(id) ~ ")[0..id.sizeof];";
		
}

template Serialize(T, alias data, alias object, alias id) {
	enum Serialize = WriteHeader!(T, data, object, id) ~ ForEachMember!(T, data, object, __traits(allMembers, T));
}

ubyte[T.sizeof] serialize(I, T)(I id, T* object) {

	StaticArray!(ubyte, T.sizeof) data;

	mixin Serialize!(T, data, object, id);
	mixin(Serialize);

	return data.array;

}
