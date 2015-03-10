module sundownstandoff.collections;

struct StaticArray(T, uint size) {

	uint elements = 0;
	T[size] array;

	void opOpAssign(string op)(T element) if(op == "~") {
		array[elements++] = element;
	}


}
