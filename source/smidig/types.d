module smidig.types;

import std.variant : maxSize;

template existsInTuple(Type, Things...) {
	static if (Things.length > 0 && is(Things[0] == Type)) {
		enum existsInTuple = true;
	} else static if (Things.length > 0) {
		enum existsInTuple = existsInTuple!(Type, Things[1..$]);
	} else {
		enum existsInTuple = false;
	}
} //existsInTuple

struct ADT(T...) {

	import std.format : format;
	import std.meta : staticMap;
	import std.traits : ParameterTypeTuple;
	import std.stdio : writefln;

	alias Types = T;
	string type_name_;
	enum max_size = maxSize!T;
	void[max_size] storage_;

	this(IT)(IT thing) {

		static assert (existsInTuple!(IT, Types), format("%s doesn't exist among types(%s) for %s.",
					IT.stringof, Types.stringof, typeof(this).stringof));

		enum size = IT.sizeof;
		storage_[0..size] = (cast(void*)&thing)[0..size];
		type_name_ = IT.stringof;

	} //this

	void opAssign(ref typeof(this) other) {
		type_name_ = other.type_name_;
		storage_ = other.storage_;
	} //opAssign

	void opAssign(IT)(IT other) {

		static assert (existsInTuple!(IT, Types), format("%s doesn't exist among types(%s) for %s.",
					IT.stringof, Types.stringof, typeof(this).stringof));

		enum size = IT.sizeof;
		storage_[0..size] = (cast(void*)&other)[0..size];
		type_name_ = IT.stringof;

	} //opAssign

	void opOpAssign(string op, OT)(OT other) {

		import std.format : format;

		if (type_name_ == type_name_.init) {

			this = other;

		} else {

			assert(OT.stringof == type_name_, format("OT was: %s, expected: %s", OT.stringof, type_name_));
			mixin(q{ *(cast(OT*)storage_) %s= other; }.format(op));

		}

	} //opOpAssign

	auto opBinary(string op, OT)(OT other) {

		if (type_name_ == type_name_.init) {

			return other;

		} else {

			assert(OT.stringof == type_name_, format("rhs was: %s, expected: %s", OT.stringof, type_name_));

			auto casted = cast(OT*)(storage_.ptr);
			mixin(q{ return *casted %s other; }.format(op));

		}

	} //opBinary

	auto ref get(IT)() {

		static assert (existsInTuple!(IT, Types), format("%s doesn't exist among types(%s) for %s.",
					IT.stringof, Types.stringof, typeof(this).stringof));

		assert(type_name_ == IT.stringof, format("%s doesn't equal %s", type_name_, IT.stringof));

		return *(cast(IT*)storage_.ptr);

	} //get

} //ADT

auto visit(ST, F...)(auto ref ST thing) {

	import std.stdio : writefln;
	import std.traits : ReturnType, ParameterTypeTuple;

	alias RetType = ReturnType!(F[0]);

	foreach (i, func; F) {

		alias ParamType = ParameterTypeTuple!func[0];
		if (ParamType.stringof == thing.type_name_) {
			return func(*(cast(ParamType*)thing.storage_.ptr));
		}

		static if (ParameterTypeTuple!func[0].stringof == ST.stringof) {  //always call last if param is itself
			if (i == F.length - 1) {
				return func(thing);
			}
		}

	}

	assert(false); //FIXME look at this later :I

} //visit

version (unittest) {

	import std.stdio : writefln;

	struct Other {
		int var;
	}

	alias Test = ADT!(int, float, double, string);
	alias SomeADT = ADT!(Other, Test, Thing);

	struct Thing {
		SomeADT[] adts;
	}

}

@name("ADT 1: visit")
unittest {

	auto something = Other(25);
	auto adt = SomeADT(something);
	assert(something == adt.get!Other());

	auto something_else = Test(25);
	adt = something_else;

	assert(something_else == adt.get!Test);

	adt.visit!(SomeADT,
		(int t) => writefln("i'm an integer: %s", t),
		(Test t) => writefln("i'm a Test: %s", t)
	)();

}
