module smidig.defs.render;

import smidig.ecs : EntityID;
import smidig.event : Event, EventID;
import smidig.math : Vec2i;

enum DrawEventType : EventID {

	RenderSprite,
	RenderLine

} //EventType

struct RenderSpriteCommand {
	import smidig.resource : ResourceID;

	immutable EntityID entity;
	immutable ResourceID resource;
	immutable Vec2i position;

	this(EntityID entity, ResourceID resource, Vec2i position) {

	}

} //RenderSpriteCommand

struct RenderLineCommand {

} //RenderLineCommand

alias RenderSpriteEvent = Event!(DrawEventType.RenderSprite, RenderSpriteCommand);
