module blindfire.netmsg;

enum EntityType {
	UNIT
}

/* used in the header for net messages to the game, create creates enties, destroy kills them, update modifies */
enum UpdateType {
	JOIN, //join session?
	CREATE, //create entity
	DESTROY, //destroy entity
	UPDATE //update state in ecs
}


// game messages and shit
struct UserDataMessage {
	
}
