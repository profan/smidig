module blindfire.serialize;

import blindfire.engine.gl;
import blindfire.engine.ecs;
import blindfire.engine.defs;
import blindfire.engine.math;
import blindfire.engine.net : NetVar;
import blindfire.engine.stream : InputStream, OutputStream;

import blindfire.sys;
import blindfire.action;

enum networked = "networked";
enum ignore = "ignore";

template isAttribute(alias curAttr, alias Attr) {
	enum isAttribute = is(typeof(curAttr) == typeof(Attr)) && curAttr == Attr;
} //isAttribute

template hasAttribute(T, alias Member, alias Attribute, Attributes...) {

	static if (Attributes.length > 0 && isAttribute!(Attribute, Attributes[0])) {

		enum hasAttribute = true;

	} else static if (Attributes.length > 0) {

		enum hasAttribute = hasAttribute!(T, Member, Attribute, Attributes[1 .. $]);

	} else {

		enum hasAttribute = false;

	}

} //hasAttribute

template getAttributes(T, alias Member) {
	enum getAttributes = __traits(getAttributes, __traits(getMember, T, Member));
} //getAttributes

template Identifier(alias Sym) {
	enum Identifier = __traits(identifier, Sym);
} //Identifier

template StringIdentifier(alias T, alias Member) {
	enum StringIdentifier = typeof(Symbol!(T, Member)).stringof;
} //StringIdentifier

template Symbol(alias T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
} //Symbol

template Symbol(T, alias Member) {
	enum Symbol = __traits(getMember, T, Member);
} //Symbol

template isPOD(T) {
	enum isPOD = __traits(isPOD, T);
} //isPOD

template NetVarToSym(T, alias Member) {
	enum NetVarToSym = Symbol!(T, Member).variable;
} //NetVarToSym

mixin template DoSerializable() {

	__gshared immutable ActionType type = ActionIdentifier[typeof(this).stringof];
	ActionType identifier() const {
		return type;
	}

	void serialize(ref OutputStream buf) {
		mixin(MakeTypeSerializable!(typeof(this), typeof(this).tupleof));
	}

} //DoSerializable

template MakeSerializable(Types...) {

	static if (Types.length > 0) {

		enum Type = Types[0].stringof;
		enum MakeSerializable = 
			"void serialize(OutputStream buf) {"
			~ MakeTypeSerializable!(Types[0], Types[0].tupleof) 
			~ "}" ~ MakeSerializable!(Types[1..$]);

	} else {

		enum MakeSerializable = "";

	}

} //MakeSerializable

template MakeTypeSerializable(T, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0].stringof))) {

		enum MakeTypeSerializable = AddSerialization!(T, members[0]) ~ MakeTypeSerializable!(T, members[1..$]);

	} else static if (members.length > 0) {

		enum MakeTypeSerializable = MakeTypeSerializable!(T, members[1..$]);

	} else {

		enum MakeTypeSerializable = "";

	}

} //MakeTypeSerializable

template SizeString(alias Symbol) {

	enum SizeString = to!string(Symbol.sizeof);

} //SizeString

template AddSerialization(T, alias Member) {

	enum AddSerialization = "buf.write("~Member.stringof~");";

} //AddSerialization

template DeSerializeEachMember(T, alias data, alias object, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum DeSerializeEachMember = Identifier!(object) ~ "." ~ members[0] ~ " = " ~
				Identifier!(data) ~ ".read!(" ~ mixin("typeof("~Identifier!(object)~"."~members[0]~").stringof") ~ ")();" 
				~ DeSerializeEachMember!(T, data, object, members[1 .. $]);


	} else static if (members.length > 0) {

		enum DeSerializeEachMember = DeSerializeEachMember!(T, data, object, members[1 .. $]);

	} else {

		enum DeSerializeEachMember = "";

	}


} //DeSerializeEachMember

template Serialize(T, alias data, alias object) {
	enum Serialize = SerializeEachMember!(T, data, object, T.tupleof);
} //Serialize

template DeSerialize(T, alias data, alias object) {
	enum DeSerialize = DeSerializeEachMember!(T, data, object, __traits(allMembers, T)); //this is until the identifier shit is fix
} //DeSerialize

template TotalNetSize(T, members...) {

	static if (members.length > 0 && hasAttribute!(T, members[0], networked, getAttributes!(T, members[0]))) {

		enum TotalNetSize = typeof(__traits(getMember, T, members[0]).bytes).sizeof + TotalNetSize!(T, members[1 .. $]);

	} else static if (members.length > 0) {

		enum TotalNetSize = TotalNetSize!(T, members[1 .. $]);

	} else {

		enum TotalNetSize = 0;

	}

} //TotalNetSize

template MemberSize(T) {
	enum MemberSize = TotalNetSize!(T, __traits(allMembers, T));
} //MemberSize

void serialize(B, T)(ref B data, T* object) {

	mixin Serialize!(T, data, object);
	mixin(Serialize);

} //serialize

void deserialize(T)(ref InputStream data, T* object) {

	mixin DeSerialize!(T, data, object);
	mixin(DeSerialize);

} //deserialize
