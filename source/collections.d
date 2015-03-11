module sundownstandoff.collections;

struct StaticArray(T, uint size) {

	uint elements = 0;
	T[size] array;

	void opOpAssign(string op: "~")(T element) {
		array[elements++] = element;
	}


}
