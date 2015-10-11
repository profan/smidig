module blindfire.defs;

import std.socket : InternetAddress;
import std.datetime : TickDuration;

import blindfire.engine.event : Event, EventID, EventManager, expandEventsToMap;
import blindfire.engine.state : StateID;

// game states
enum State : StateID {

	Menu,
	Joining,
	Game,
	Options,
	Lobby,
	Waiting

} //State

alias ClientConnectEvent = Event!(EventType.ClientConnect, InternetAddress);
alias ClientDisconnectEvent = Event!(EventType.ClientDisconnect, bool);
alias ClientSetConnectedEvent = Event!(EventType.ClientSetConnected, bool);
alias StartGameEvent = Event!(EventType.StartGame, bool);
alias GameCreatedEvent = Event!(EventType.GameCreated, bool);

//console commands
alias SetTickrateEvent = Event!(EventType.SetTickrate, TickDuration);
alias PushGameStateEvent = Event!(EventType.PushGameState, State);

enum EventType : EventID {

	//general
	ClientConnect,
	ClientDisconnect,
	ClientSetConnected,
	StartGame,
	GameCreated,

	//console commands
	SetTickrate,
	PushGameState

} //EventType

mixin(expandEventsToMap!("EventIdentifier",
						 ClientConnectEvent,
						 ClientDisconnectEvent,
						 ClientSetConnectedEvent,
						 StartGameEvent,
						 GameCreatedEvent,
						 SetTickrateEvent,
						 PushGameStateEvent));