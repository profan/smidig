module blindfire.defs;

import std.socket : InternetAddress;

import blindfire.engine.event : Event, EventID, EventManager;

alias ClientConnectEvent = Event!(EventType.ClientConnect, InternetAddress);
alias ClientDisconnectEvent = Event!(EventType.ClientDisconnect, bool);
alias ClientSetConnectedEvent = Event!(EventType.ClientSetConnected, bool);
alias CreateGameEvent = Event!(EventType.CreateGame, bool);
alias GameCreatedEvent = Event!(EventType.GameCreated, bool);

alias EventManagerType = EventManager!(EventType.max+1);

enum EventType : EventID {
	ClientConnect,
	ClientDisconnect,
	ClientSetConnected,
	CreateGame,
	GameCreated
} //EventType
