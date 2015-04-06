module blindfire.resource;

import blindfire.gl : Texture;

//some resource loading shenanigans, this will probably become some horrid singleton or global.

alias ResourceID = uint;

class ResourceManager {

	//some structure mapping an identifier to a texture
	private void*[ResourceID] resources;
	private static __gshared ResourceManager instance;
		
	static ResourceManager get() {

		if (instance is null) {
			instance = new ResourceManager();
		}

		return instance;

	}

	__gshared void set_resource(T)(T* resource, ResourceID identifier) {

		resources[identifier] = resource;

	}

	__gshared T* get_resource(T)(ResourceID identifier) {

		return cast(T*)resources[identifier];

	}

} //ResourceManager
