module blindfire.engine.math;

T normalize(T)(T val, T min, T max, T val_max) pure @nogc nothrow {
	return (min + val) / (val_max / (max - min));
} //normalize

unittest {

	import std.string : format;
	import std.stdio: writefln;

	float[5] values = [1, 2, 3, 4, 5];

	float min = 0, max = 1;
	float val_max = 5;
	foreach (value; values) {
		float n = normalize(value, min, max, val_max);
		assert(n >= min && n <= max, format("expected value in range, was %f", n));
	}

}

/* vector related ufcs extensions */
T rotate(T)(ref T vec, double radians) nothrow @nogc pure if (is(T : Vector) && T._N == 2) {

	auto ca = cos(radians);
	auto sa = sin(radians);
	return T(ca*vec.x - sa*vec.y, sa*vec.x + ca*vec.y);

} //rotate

T._T squaredDistanceTo(T)(ref T vec, ref T other_vec) nothrow @nogc pure if (is(T : Vector) && T._N == 2) {

	return ((vec.x - other_vec.x)*(vec.x - other_vec.x)) -
		((vec.y - other_vec.y)*(vec.y-other_vec.y));

} //squaredDistanceTo