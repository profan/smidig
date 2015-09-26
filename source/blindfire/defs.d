module blindfire.defs;

import std.socket : InternetAddress;
import std.datetime : TickDuration;

import blindfire.engine.event : Event, EventID, EventManager, expandEventsToMap;
import blindfire.engine.state : State;

alias ClientConnectEvent = Event!(EventType.ClientConnect, InternetAddress);
alias ClientDisconnectEvent = Event!(EventType.ClientDisconnect, bool);
alias ClientSetConnectedEvent = Event!(EventType.ClientSetConnected, bool);
alias CreateGameEvent = Event!(EventType.CreateGame, bool);
alias GameCreatedEvent = Event!(EventType.GameCreated, bool);

//console commands
alias SetTickrateEvent = Event!(EventType.SetTickrate, TickDuration);
alias PushGameStateEvent = Event!(EventType.PushGameState, State);

enum EventType : EventID {

	//general
	ClientConnect,
	ClientDisconnect,
	ClientSetConnected,
	CreateGame,
	GameCreated,

	//console commands
	SetTickrate,
	PushGameState

} //EventType

mixin(expandEventsToMap!(ClientConnectEvent,
						 ClientDisconnectEvent,
						 ClientSetConnectedEvent,
						 CreateGameEvent,
						 GameCreatedEvent,
						 SetTickrateEvent,
						 PushGameStateEvent));