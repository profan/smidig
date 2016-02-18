module smidig.util;

import smidig.defs : Vec2i;
import smidig.gl : FontAtlas, RenderTarget;

void render_string(string format, Args...)(FontAtlas* atlas, ref RenderTarget window, ref Vec2i offset, Args args) {
	render_string!(format)(*atlas, window, offset, args);
} //render_string

ref FontAtlas render_string(string format, Args...)(ref FontAtlas atlas, ref RenderTarget window, ref Vec2i offset, Args args) {

	char[format.length*2] buf;
	const char[] str = cformat(buf[], format, args);

	atlas.renderText(window, str, offset.x, offset.y, 1, 1, 0xffffff);
	offset.y += atlas.char_height*2;

	return atlas;

} //render_string

/**
 * A safer D interface to sprintf, uses a supplied char buffer for formatting, returns a slice.
 * You will most definitely die a fiery death if the format string doesn't have a null terminator.
*/
const(char[]) cformat(Args...)(char[] buf, in char[] format, Args args) {

	import core.stdc.stdio : snprintf;

	auto chars = snprintf(buf.ptr, buf.length, format.ptr, args);
	const char[] str = buf[0 .. (chars > 0) ? chars+1 : 0];

	return str;

} //cformat

/**
 * Convenience function which calls cformat on a temporary char buffer,
 * which is then returned as a value.
*/
const(char[Size]) tempformat(size_t Size, Args...)(in char[] format, Args args) {

	char[Size] temp_buf;
	cformat(temp_buf, format, args);

	return temp_buf;

} //tempformat

/**
 * Generates a compile time hashmap with a given name, key type and value type for up to $(D sizeof(ValueType.sizeof * 8)) elements.
 * Maps keys given as args to values increasing by ^2, to create something which can be checked by bitwise and.
*/
string makeFlagEnum(string EnumName, KeyType, ValueType, Args...)(Args args) {

	import std.string : format;

	enum max_size = ValueType.sizeof * 8;
	static assert(args.length <= max_size,
		   format("can't hold %d flags in type %s (%d bits)", args.length, ValueType.stringof, max_size));

	import std.string : format;

	string mixinFields() {

		auto str = "";

		foreach (i, field; args) {
			auto n = i ^ 2;
			str ~= q{%s : 0x%s}.format(field, n);
			if (i < args.length-1) str ~= ",";
		}

		return str;

	} //mixinFields

	auto str = q{enum : %s[%s] {
		%s = [%s]
	}}.format(KeyType.stringof, ValueType.stringof, EnumName, mixinFields());

	return str;

} //makeFlagEnum

RT withGCArena(RT)(RT delegate() func, void delegate() after_func) {

	import gcarena : useCleanArena;
	RT rt;

	{
		auto ar = useCleanArena();
		rt = func();
	}

	after_func();

	return rt;

} //withGCArena
