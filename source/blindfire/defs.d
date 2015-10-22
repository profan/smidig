module blindfire.defs;

import blindfire.engine.event : Event, EventID, EventManager, expandEventsToMap;
import blindfire.engine.state : StateID;

enum EventType : EventID {
	AnalogAxis,
	AnalogRot
}

struct AxisPayload {
	uint id;
	int value;
}

alias AnalogAxisEvent = Event!(EventType.AnalogAxis, AxisPayload);
alias AnalogRotEvent = Event!(EventType.AnalogRot, AxisPayload);

mixin(expandEventsToMap!("EventIdentifier", AnalogAxisEvent, AnalogRotEvent));