module blindfire.engine.util;

import blindfire.engine.defs : Vec2i;
import blindfire.engine.text : FontAtlas;
import blindfire.engine.window : Window;

void render_string(string format, Args...)(FontAtlas* atlas, Window* window, ref Vec2i offset, Args args) {
	render_string!(format)(*atlas, window, offset, args);
}

void render_string(string format, Args...)(ref FontAtlas atlas, Window* window, ref Vec2i offset, Args args) {

	import std.string : sformat;

	char[format.length*2] buf;
	const char[] str = sformat(buf, format, args); //this allocates! wtf!!!!
	atlas.render_text(window, str, offset.x, offset.y, 1, 1, 0xffffff);
	offset.y += atlas.char_height*2;

}

import core.stdc.stdlib : free, malloc;
import core.stdc.stdio : rewind, fopen, fclose, fread, ftell, fseek, printf, FILE, SEEK_END;

size_t get_filesize(FILE *file) nothrow @nogc {

	fseek(file, 0, SEEK_END);
	long size = ftell(file);
 	rewind(file);
	if (size <= 0) printf("Invalid file size. \n");

	return cast(size_t)size; //TODO consider the sanity of this

}

size_t fread_str(char *buf, size_t buf_size, size_t filesize, FILE *file) nothrow @nogc {

	size_t result = fread(buf, buf_size, filesize, file);
	buf[filesize] = '\0';

	return result;

}

char* load_file(const char *filename) nothrow @nogc {

	FILE *file;
	size_t result;
	file = fopen(filename, "r");
	if (file == null) printf("File error (does it exist?). \n");
	size_t filesize = get_filesize(file);
	
	char *buf = cast(char*)malloc((char.sizeof*filesize)+1);
	if (!buf) printf("Memory error. \n");
	result = fread_str(buf, (*buf).sizeof, filesize, file);
	if (result != filesize) printf("Error reading file: %s, filesize was: %zu, expected: %zu. \n", 
		filename, result, filesize);
	fclose(file);

	return buf;

}

string makeFlagEnum(string EnumName, KeyType, ValueType, Args...)(Args args) {

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