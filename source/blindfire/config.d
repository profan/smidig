module blindfire.config;

import std.file : exists, read, write;
import std.algorithm : splitter;
import std.stdio : writefln;

struct ConfigMap {

	enum MAX_KEY_LENGTH = 64;
	enum MAX_VALUE_LENGTH = 64;
	alias Key = immutable char[];
	alias Value = char[];

	private const char[] file_name;
	private Value[Key] config;

	this(in char[] file_name) {

		this.file_name = file_name[];

		if (exists(file_name)) {
			auto data = load_file(file_name);
			parse_file(data);
		}

	} //this

	const(char[]) load_file(in char[] file_name) {

		auto input = cast(const char[])read(file_name);
		return input;

	} //load_file

	void parse_file(in char[] lines) {
		
		foreach (line; lines.splitter("\n")) {

			auto parts = line.splitter("=");
			if (parts.empty) continue;

			auto key = parts.front;
			parts.popFront();

			auto value = parts.front;
			config[key] = value.dup;

		}

	} //parse_file

	void save_file() {

		string buf = "";
		foreach (key, value; config) {
			buf ~= (key ~ "=" ~ value ~ "\n");
		}

		write(file_name, buf);

	} //save_file

	void set(in Key key, in Value value) {
		config[key] = value.dup;
	} //set

	const(Value) get(in Key key) const {

		if (key in config) {
			return config[key];
		} //get

		return "";

	}

} //ConfigMap
