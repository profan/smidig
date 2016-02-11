module smidig.types;

import std.variant : maxSize;
import tested : name;

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

	this(IT)(auto ref IT thing) {

		import std.algorithm : move;

		static assert (existsInTuple!(IT, Types), format("%s doesn't exist among types(%s) for %s.",
					IT.stringof, Types.stringof, typeof(this).stringof));

		enum size = IT.sizeof;
		move(thing, cast(IT)(*cast(IT*)(storage_.ptr)));
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

alias Result(T, E) = ADT!(T, E);

version(unittest) {

	enum SomeError {
		NoPermission,
		FileNotFound
	}

}

@name("Algebraic 1: error handling test")
unittest {

	alias SomeResult = ADT!(char[], SomeError);

	SomeResult value = SomeError.FileNotFound;

	auto result = value.visit!(SomeResult,
		(char[] c) => true,
		(SomeError err) => false)();

	assert(!result);

}

import std.algorithm : move;

struct Nullable(T)
{
    private T _value;
    private bool _isNull = true;

/**
Constructor initializing $(D this) with $(D value).
Params:
    value = The value to initialize this `Nullable` with.
 */
    this(T value)
    {
        _value = move(value);
        _isNull = false;
    }

	this(ref T value)
	{
        _value = move(value);
        _isNull = false;
	}

    template toString()
    {
        import std.format : FormatSpec, formatValue;
        // Needs to be a template because of DMD @@BUG@@ 13737.
        void toString()(scope void delegate(const(char)[]) sink, FormatSpec!char fmt)
        {
            if (isNull)
            {
                sink.formatValue("Nullable.null", fmt);
            }
            else
            {
                sink.formatValue(_value, fmt);
            }
        }

        // Issue 14940
        void toString()(scope void delegate(const(char)[]) @safe sink, FormatSpec!char fmt)
        {
            if (isNull)
            {
                sink.formatValue("Nullable.null", fmt);
            }
            else
            {
                sink.formatValue(_value, fmt);
            }
        }
    }

/**
Check if `this` is in the null state.
Returns:
    true $(B iff) `this` is in the null state, otherwise false.
 */
    @property bool isNull() const @safe pure nothrow
    {
        return _isNull;
    }

///
unittest
{
    Nullable!int ni;
    assert(ni.isNull);

    ni = 0;
    assert(!ni.isNull);
}

// Issue 14940
@safe unittest
{
    import std.array : appender;
    import std.format : formattedWrite;

    auto app = appender!string();
    Nullable!int a = 1;
    formattedWrite(app, "%s", a);
    assert(app.data == "1");
}

/**
Forces $(D this) to the null state.
 */
    void nullify()()
    {
        .destroy(_value);
        _isNull = true;
    }

///
unittest
{
    Nullable!int ni = 0;
    assert(!ni.isNull);

    ni.nullify();
    assert(ni.isNull);
}

/**
Assigns $(D value) to the internally-held state. If the assignment
succeeds, $(D this) becomes non-null.
Params:
    value = A value of type `T` to assign to this `Nullable`.
 */
    void opAssign()(T value)
    {
        _value = value;
        _isNull = false;
    }

/**
    If this `Nullable` wraps a type that already has a null value
    (such as a pointer), then assigning the null value to this
    `Nullable` is no different than assigning any other value of
    type `T`, and the resulting code will look very strange. It
    is strongly recommended that this be avoided by instead using
    the version of `Nullable` that takes an additional `nullValue`
    template argument.
 */
unittest
{
    //Passes
    Nullable!(int*) npi;
    assert(npi.isNull);

    //Passes?!
    npi = null;
    assert(!npi.isNull);
}

/**
Gets the value. $(D this) must not be in the null state.
This function is also called for the implicit conversion to $(D T).
Returns:
    The value held internally by this `Nullable`.
 */
    @property T get() @system
    {
        enum message = "Called `get' on null Nullable!" ~ T.stringof ~ ".";
        assert(!isNull, message);
        return move(_value);
    }

///
unittest
{
    import std.exception: assertThrown, assertNotThrown;

    Nullable!int ni;
    //`get` is implicitly called. Will throw
    //an AssertError in non-release mode
    assertThrown!Throwable(ni == 0);

    ni = 0;
    assertNotThrown!Throwable(ni == 0);
}

/**
Implicitly converts to $(D T).
$(D this) must not be in the null state.
 */
    alias get this;
}
