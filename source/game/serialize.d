module sundownstandoff.serialize;

import profan.collections : StaticArray;
import sundownstandoff.net : NetVar;
import std.bitmanip;

enum networked = "networked";

static template isAttribute(alias curAttr, alias Attr) {
	enum isAttribute = is(typeof(curAttr) == typeof(Attr));
}

static template hasAttribute(T, alias Member, alias Attribute, Attributes...) {

	static if (Attributes.length > 0 && isAttribute!(Attribute, Attributes[0])) {

		enum hasAttribute = true;

	} else static if (Attributes.length > 0) {

		enum hasAttribute = hasAttribute!(T, Member, Attribute, Attributes[1 .. $]);

	} else {

		enum hasAttribute = false;

	}

}

static template getAttributes(T, alias Member) {
	enum getAttributes = __traits(getAttributes, __traits(getMember, T, Member));
}

static template Identifier(alias Sym) {
	enum Identifier = __traits(identifier, Sym);
}

static template Symbol(alias T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

static template Symbol(T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
}

static template isPOD(T) {
	enum isPOD = __traits(isPOD, T);
}

static template NetVarToSym(T, alias Member) {
	enum NetVarToSym = Symbol!(T, Member).variable;
}

static template ForEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		/*Identifier!(Symbol!(object, members[0]).variable)*/ 
		static if (isPOD!(typeof(NetVarToSym!(T, members[0])))) {

			enum ForEachMember = ForEachMember!(typeof(NetVarToSym!(T, members[0])), data, object, 
				__traits(allMembers, typeof(NetVarToSym!(T, members[0]))));

		} else {

			enum ForEachMember = 
				Identifier!(data) ~ " ~= nativeToBigEndian(" ~ Identifier!(object) ~ "." ~ members[0] ~ ".variable);" 
					~ ForEachMember!(T, data, members[1 .. $]);

		}

	} else static if (members.length > 0) {

		enum ForEachMember = ForEachMember!(T, data, members[1 .. $]);

	} else {

		enum ForEachMember = "";

	}

}

static template Serialize(T, alias data, alias object) {
	enum Serialize = ForEachMember!(T, data, object, __traits(allMembers, T));
}

byte[T.sizeof] serialize(T)(T* object) {

	StaticArray!(byte, T.sizeof) data;

	mixin Serialize!(T, data, object);
	mixin(Serialize);

	return data.array;

}
