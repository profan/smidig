module blindfire.engine.defs;

import gfm.math : Vector, Matrix;

import blindfire.engine.event : Event, EventID, expandEventsToMap;
import blindfire.engine.ecs : EntityID;

//Network related
alias ClientID = ubyte;
alias LocalEntityID = ulong;

//OpenGL maths related
alias Vec2i = Vector!(int, 2);
alias Vec2f = Vector!(float, 2);
alias Vec3f = Vector!(float, 3);
alias Vec4f = Vector!(float, 4);
alias Mat3f = Matrix!(float, 3, 3);
alias Mat4f = Matrix!(float, 4, 4);

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

//networking related
import blindfire.engine.net : Command;

enum NetEventType : EventID {
	AssignID,
	SetConnected,
	Disconnected,
	GameUpdate
} //NetEventType

enum DisconnectReason : uint {
	HostDisconnected
} //DisconnectReason

alias AssignIDEvent = Event!(NetEventType.AssignID, ClientID);
alias IsConnectedEvent = Event!(NetEventType.SetConnected, bool);
alias DisconnectedEvent = Event!(NetEventType.Disconnected, DisconnectReason);
alias GameUpdateEvent = Event!(NetEventType.GameUpdate, ubyte[]);
