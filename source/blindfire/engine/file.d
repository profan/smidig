module blindfire.engine.file;

import core.stdc.stdio;
import core.stdc.stdlib;
import blindfire.engine.collections : String, StringBuffer;

StringBuffer read_file(in char[] file_path) {

	FILE *file;
	size_t result;
	file = fopen(file_path.ptr, "r");

	if (file == null) {
		printf("File error (does it exist?). \n");
	}

	size_t filesize = get_filesize(file);
	auto string_buf = StringBuffer(filesize + 1);

	result = fread_str(cast(char*)string_buf.c_str(), char.sizeof, filesize, file);
	if (result != filesize) {
		printf("Error reading file: %s, filesize was: %zu, expected: %zu. \n", 
			   file_path.ptr, result, filesize);
	}

	fclose(file);

	/* readjust length, since direct manip has occured */
	string_buf.scan_to_null();

	return string_buf;

} //read_file

void save_file(in char[] path, String contents) {

} //save_file

size_t get_filesize(FILE *file) nothrow @nogc {

	fseek(file, 0, SEEK_END);
	long size = ftell(file);
	rewind(file);

	if (size <= 0) {
		printf("Invalid file size. \n");
	}

	return cast(size_t)size; //TODO consider the sanity of this

} //get_filesize

size_t fread_str(char *buf, size_t buf_size, size_t filesize, FILE *file) nothrow @nogc {

	size_t result = fread(buf, buf_size, filesize, file);
	buf[filesize] = '\0';

	return result;

} //fread_str