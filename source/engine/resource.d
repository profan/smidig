module blindfire.resource;

import blindfire.gl : Texture;

//some resource loading shenanigans, this will probably become some horrid singleton or global.

alias ResourceID = uint;

class ResourceManager {

	//some structure mapping an identifier to a texture
	Texture[ResourceID] textures;

	this() {

	}

	void load_texture(in char[] file_name, ResourceID identifier) {
		
		textures[identifier] = Texture(file_name);

	}

	ref auto get_texture(ResourceID identifier) {

		return textures[identifier];

	}

} //ResourceManager
