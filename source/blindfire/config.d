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
			auto data = loadFile(file_name);
			parseFile(data);
		}

	} //this

	const(char[]) loadFile(in char[] file_name) {

		auto input = cast(const char[])read(file_name);
		return input;

	} //loadFile

	void parseFile(in char[] lines) {
		
		foreach (line; lines.splitter("\n")) {

			auto parts = line.splitter("=");
			if (parts.empty) continue;

			auto key = parts.front;
			parts.popFront();

			auto value = parts.front;
			config[key] = value.dup;

		}

	} //parseFile

	void saveFile() {

		string buf = "";
		foreach (key, value; config) {
			buf ~= (key ~ "=" ~ value ~ "\n");
		}

		write(file_name, buf);

	} //saveFile

	void set(in Key key, in Value value) {
		config[key] = value.dup;
	} //set

	const(Value) get(in Key key) const {

		if (auto item = key in config) {
			return *item;
		} //get

		return "";

	}

} //ConfigMap
