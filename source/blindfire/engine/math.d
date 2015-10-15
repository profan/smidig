module blindfire.engine.math;

import gfm.math : Vector, Matrix;

//OpenGL maths related
alias Vec2i = Vector!(int, 2);
alias Vec2f = Vector!(float, 2);
alias Vec3f = Vector!(float, 3);
alias Vec4f = Vector!(float, 4);
alias Mat3f = Matrix!(float, 3, 3);
alias Mat4f = Matrix!(float, 4, 4);

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

bool point_in_rect(int x, int y, int r_x, int r_y, int w, int h) nothrow @nogc pure {
	return (x < r_x + w && y < r_y + h && x > r_x && y > r_y);
} //point_in_rect

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
