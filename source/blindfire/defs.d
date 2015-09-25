module blindfire.defs;

import std.socket : InternetAddress;

import blindfire.engine.event : Event, EventID, EventManager;

alias ClientConnectEvent = Event!(EventType.ClientConnect, InternetAddress);
alias ClientDisconnectEvent = Event!(EventType.ClientDisconnect, bool);
alias ClientSetConnectedEvent = Event!(EventType.ClientSetConnected, bool);
alias CreateGameEvent = Event!(EventType.CreateGame, bool);
alias GameCreatedEvent = Event!(EventType.GameCreated, bool);

//console commands
import std.datetime : TickDuration;
alias SetTickrateEvent = Event!(EventType.SetTickrate, TickDuration);

enum EventType : EventID {
	ClientConnect,
	ClientDisconnect,
	ClientSetConnected,
	CreateGame,
	GameCreated,
	SetTickrate
} //EventType
