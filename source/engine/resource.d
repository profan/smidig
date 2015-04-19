module blindfire.engine.resource;

import blindfire.engine.gl : Texture;

//some resource loading shenanigans, this will probably become some horrid singleton or global.

alias ResourceID = uint;

class ResourceManager {

	struct ResourceHandle {

		void* resource;
		string type;

	}

	//some structure mapping an identifier to a texture
	private ResourceHandle[ResourceID] resources;
	private static __gshared ResourceManager instance = new ResourceManager;
		
	static ResourceManager get() {

		return instance;

	}

	__gshared void set_resource(T)(T* resource, ResourceID identifier) {

		resources[identifier] = ResourceHandle(resource, T.stringof);

	}

	__gshared T* get_resource(T)(ResourceID identifier) {

		import std.string : format;
		assert (resources[identifier].type == T.stringof, format("tried to retrieve resource of type: %s with type %s", resources[identifier].type, T.stringof));
		return cast(T*)resources[identifier].resource;

	}

} //ResourceManager
