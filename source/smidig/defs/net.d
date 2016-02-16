module smidig.defs.net;

import smidig.event : Event, EventID;
import smidig.ecs : EntityID;
import smidig.math : Vec2i;

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

import std.meta : AliasSeq;
alias NetEventTypes = AliasSeq!(ConnectionEvent, DisconnectionEvent, UpdateEvent, PushEvent);
