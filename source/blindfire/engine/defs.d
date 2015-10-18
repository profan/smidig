module blindfire.engine.defs;

import blindfire.engine.event : Event, EventID, expandEventsToMap;
import blindfire.engine.ecs : EntityID;
import blindfire.engine.math : Vec2i;

//Network related
alias ClientID = ubyte;
alias LocalEntityID = uint; //FIXME change back to ulong later

//rendering related
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

enum NetEventType : EventID {
	Connection,
	Disconnection,
	Update
} //NetEventType

enum DisconnectReason : uint {
	HostDisconnected
} //DisconnectReason

struct Update {

	ENetPeer* peer;
	const(void[]) data;

	alias data this;

} //Update

import derelict.enet.enet;
alias ConnectionEvent = Event!(NetEventType.Connection, ENetPeer*);
alias DisconnectionEvent = Event!(NetEventType.Disconnection, ENetPeer*);
alias UpdateEvent = Event!(NetEventType.Update, Update);

mixin(expandEventsToMap!("NetEventIdentifier",
	ConnectionEvent,
	DisconnectionEvent,
	UpdateEvent));