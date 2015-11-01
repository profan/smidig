module blindfire.engine.defs.render;

import blindfire.engine.ecs : EntityID;
import blindfire.engine.event : Event, EventID;
import blindfire.engine.math : Vec2i;

enum DrawEventType : EventID {

	RenderSprite,
	RenderLine

} //EventType

struct RenderSpriteCommand {
	import blindfire.engine.resource : ResourceID;

	immutable EntityID entity;
	immutable ResourceID resource;
	immutable Vec2i position;

	this(EntityID entity, ResourceID resource, Vec2i position) {

	}

} //RenderSpriteCommand

struct RenderLineCommand {

} //RenderLineCommand

alias RenderSpriteEvent = Event!(DrawEventType.RenderSprite, RenderSpriteCommand);
