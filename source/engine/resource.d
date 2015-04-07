module blindfire.resource;

import blindfire.gl : Texture;

//some resource loading shenanigans, this will probably become some horrid singleton or global.

alias ResourceID = uint;

class ResourceManager {

	//some structure mapping an identifier to a texture
	private void*[ResourceID] resources;
	private static __gshared ResourceManager instance = new ResourceManager;
		
	static ResourceManager get() {

		return instance;

	}

	__gshared void set_resource(T)(T* resource, ResourceID identifier) {

		resources[identifier] = resource;

	}

	__gshared T* get_resource(T)(ResourceID identifier) {

		return cast(T*)resources[identifier];

	}

} //ResourceManager
