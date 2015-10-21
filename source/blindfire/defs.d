module blindfire.defs;

import blindfire.engine.event : Event, EventID, EventManager, expandEventsToMap;
import blindfire.engine.state : StateID;

enum EventType : EventID {
	AnalogAxis
}

struct AxisPayload {
	uint id;
	int value;
}

alias AnalogAxisEvent = Event!(EventType.AnalogAxis, AxisPayload);

mixin(expandEventsToMap!("EventIdentifier", AnalogAxisEvent));