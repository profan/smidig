module blindfire.serialize;

import profan.collections : StaticArray;
import blindfire.net : NetVar;
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

template SerializeEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum SerializeEachMember =
			Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ members[0] ~ ".bytes;"
				~ SerializeEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum SerializeEachMember = SerializeEachMember!(T, data, members[1 .. $]);

	} else {

		enum SerializeEachMember = "";

	}

}

template DeSerializeEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum DeSerializeEachMember =
			Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ members[0] ~ ".bytes;"
				~ DeSerializeEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum DeSerializeEachMember = DeSerializeEachMember!(T, data, members[1 .. $]);

	} else {

		enum DeSerializeEachMember = "";

	}


}

//write identifier(type of component) and entity id, header of component message.
template WriteHeader(T, alias data, alias object) {
	enum WriteHeader =
		Identifier!(data) ~ " ~= " ~ Identifier!(object) ~ "." ~ "identifier_bytes;";
}

template ReadHeader() {
	enum ReadHeader = "";
}

template Serialize(T, alias data, alias object) {
	enum Serialize = WriteHeader!(T, data, object) ~ SerializeEachMember!(T, data, object, __traits(allMembers, T));
}

template DeSerialize(T, alias data, alias object) {
	enum DeSerialize = ReadHeader!() ~ DeSerializeEachMember(T, data, object, __traits(allMembers, T));
}

template TotalNetSize(T, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum TotalNetSize = typeof(__traits(getMember, T, members[0])).sizeof + TotalNetSize!(T, members[1 .. $]);

	} else static if (members.length > 0) {

		enum TotalNetSize = TotalNetSize!(T, members[1 .. $]);

	} else {

		enum TotalNetSize = 0;

	}

}

template MemberSize(T) {
	enum MemberSize = TotalNetSize!(T, __traits(allMembers, T));
}

import profan.ecs : EntityID;
ubyte[MemberSize!(T)] serialize(T)(T* object) {

	StaticArray!(ubyte, MemberSize!(T)) data;

	mixin Serialize!(T, data, object);
	mixin(Serialize);

	return data.array;

}

T deserialize(T)(ubyte[] data) {

}
