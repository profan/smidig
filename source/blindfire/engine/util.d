module blindfire.engine.util;

import blindfire.engine.defs : Vec2i;
import blindfire.engine.text : FontAtlas;
import blindfire.engine.window : Window;

bool point_in_rect(int x, int y, int r_x, int r_y, int w, int h) nothrow @nogc pure {
	return (x < r_x + w && y < r_y + h && x > r_x && y > r_y);
}

void render_string(string format, Args...)(FontAtlas* atlas, Window* window, ref Vec2i offset, Args args) {
	render_string!(format)(*atlas, window, offset, args);
}

void render_string(string format, Args...)(ref FontAtlas atlas, Window* window, ref Vec2i offset, Args args) {

	import std.string : sformat;

	char[format.length*2] buf;
	const char[] str = sformat(buf, format, args);
	atlas.render_text(window, str, offset.x, offset.y, 1, 1, 0xffffff);
	offset.y += 16;

}

import core.stdc.stdlib : free, malloc;
import core.stdc.stdio : rewind, fopen, fclose, fread, ftell, fseek, printf, FILE, SEEK_END;

size_t get_filesize(FILE *file) nothrow @nogc {

	fseek(file, 0, SEEK_END);
	long size = ftell(file);
 	rewind(file);
	if (size <= 0) printf("Invalid file size. \n");

	return size;

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
	if (result != filesize) printf("Reading error. \n");
	fclose(file);

	return buf;

}
