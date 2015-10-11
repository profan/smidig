module blindfire.engine.resource;

import blindfire.engine.gl : Texture;

//some resource loading shenanigans, this will probably become some horrid singleton or global.

alias ResourceID = uint;

class ResourceManager {

	import blindfire.engine.collections : HashMap;
	import blindfire.engine.memory : IAllocator, theAllocator, make;

	struct ResourceHandle {

		void* resource;
		string type;

	} //ResourceHandle

	//some structure mapping an identifier to a texture
	private HashMap!(ResourceID, ResourceHandle) resources;

	//allocator and instance
	private static __gshared IAllocator allocator_;
	private static __gshared ResourceManager instance;

	static this() {
		this.allocator_ = theAllocator;
		if (instance is null) {
			this.instance = allocator_.make!ResourceManager();
		}
	} //static this

	this() {
		this.resources = typeof(resources)(allocator_, 32);
	} //this
		
	static ResourceManager get() {
		return instance;
	} //get

	__gshared void set_resource(T)(T* resource, ResourceID identifier) {

		resources[identifier] = ResourceHandle(resource, T.stringof);

	} //set_resource

	__gshared T* get_resource(T)(ResourceID identifier) {

		import std.string : format;
		assert (resources[identifier].type == T.stringof, format("tried to retrieve resource of type: %s with type %s", resources[identifier].type, T.stringof));

		return cast(T*)(resources[identifier].resource);

	} //get_resource

} //ResourceManager
