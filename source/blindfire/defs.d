module blindfire.defs;

import std.socket : InternetAddress;

import blindfire.engine.event : Event, EventID, EventManager;
import blindfire.engine.state : State;

alias ClientConnectEvent = Event!(EventType.ClientConnect, InternetAddress);
alias ClientDisconnectEvent = Event!(EventType.ClientDisconnect, bool);
alias ClientSetConnectedEvent = Event!(EventType.ClientSetConnected, bool);
alias CreateGameEvent = Event!(EventType.CreateGame, bool);
alias GameCreatedEvent = Event!(EventType.GameCreated, bool);

//console commands
import std.datetime : TickDuration;
alias SetTickrateEvent = Event!(EventType.SetTickrate, TickDuration);
alias PushGameStateEvent = Event!(EventType.PushGameState, State);

enum EventType : EventID {
	ClientConnect,
	ClientDisconnect,
	ClientSetConnected,
	CreateGame,
	GameCreated,
	SetTickrate,
	PushGameState
} //EventType

template expandEventsToMap(Events...) {
	enum expandEventsToMap =
		"enum : int[string] {
			EventIdentifier = [" ~ expandEvents!Events ~ "]
		}";
} //expandEventsToMap

template expandEvents(Events...) {
	import std.conv : to;
	static if (Events.length > 1) {
		enum expandEvents = "\"" ~ Events[0].stringof ~ "\" : " ~ to!string(Events[0].message_id) ~ ", "
			~ expandEvents!(Events[1..$]);
	} else static if (Events.length > 0) {
		enum expandEvents = "\"" ~ Events[0].stringof ~ "\" : " ~ to!string(Events[0].message_id)
			~ expandEvents!(Events[1..$]);
	} else {
		enum expandEvents = "";
	}
} //expandEvents

mixin(expandEventsToMap!(ClientConnectEvent,
						 ClientDisconnectEvent,
						 ClientSetConnectedEvent,
						 CreateGameEvent,
						 GameCreatedEvent,
						 SetTickrateEvent,
						 PushGameStateEvent));