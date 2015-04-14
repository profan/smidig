module blindfire.netmsg;

import blindfire.sys;

/* used in the header for net messages to the game, create creates enties, destroy kills them, update modifies */
enum UpdateType {
	JOIN, //join session?
	CREATE, //create entity
	DESTROY, //destroy entity
	UPDATE //update state in ecs
}

enum EntityType {
	UNIT
}

alias uint ComponentType;

enum : ComponentType[string] {
	ComponentIdentifier = [
		TransformComponent.stringof : 0
	]
}

struct NetMessage {
	
} //NetMessage
