module blindfire.engine.util;

import blindfire.engine.defs : Vec2i;
import blindfire.engine.window : Window;
import blindfire.engine.gl : FontAtlas;

void render_string(string format, Args...)(FontAtlas* atlas, Window* window, ref Vec2i offset, Args args) {
	render_string!(format)(*atlas, window, offset, args);
} //render_string

ref FontAtlas render_string(string format, Args...)(ref FontAtlas atlas, Window* window, ref Vec2i offset, Args args) {

	char[format.length*2] buf;
	const char[] str = cformat(buf[], format, args);

	atlas.renderText(window, str, offset.x, offset.y, 1, 1, 0xffffff);
	offset.y += atlas.char_height*2;

	return atlas;

} //render_string

const(char[]) cformat(Args...)(char[] buf, in char[] format, Args args) {

	import core.stdc.stdio : snprintf;

	auto chars = snprintf(buf.ptr, buf.length, format.ptr, args);
	const char[] str = buf[0 .. (chars > 0) ? chars+1 : 0];

	return str;

} //cformat

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