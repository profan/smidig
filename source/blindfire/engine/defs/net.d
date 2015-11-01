module blindfire.engine.defs.net;

import blindfire.engine.event : Event, EventID, expandEventsToMap;
import blindfire.engine.ecs : EntityID;
import blindfire.engine.math : Vec2i;

enum NetEventType : EventID {
	Connection,
	Disconnection,
	Update,
	Push
} //NetEventType

enum DisconnectReason : uint {
	HostDisconnected
} //DisconnectReason

public import derelict.enet.enet : ENetPeer;

struct Update {

	ENetPeer* peer;
	const(void[]) data;

	alias data this;

} //Update

alias ConnectionEvent = Event!(NetEventType.Connection, ENetPeer*);
alias DisconnectionEvent = Event!(NetEventType.Disconnection, ENetPeer*);
alias UpdateEvent = Event!(NetEventType.Update, Update);
alias PushEvent = Event!(NetEventType.Push, const(void[]));

mixin(expandEventsToMap!("NetEventIdentifier",
	ConnectionEvent,
	DisconnectionEvent,
	UpdateEvent,
	PushEvent));
