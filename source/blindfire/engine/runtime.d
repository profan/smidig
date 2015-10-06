module blindfire.engine.runtime;

import blindfire.engine.render : IRenderer, OpenGLRenderer;
import blindfire.engine.event : EventManager, EventMemory;
import blindfire.engine.net : NetworkPeer;

import blindfire.engine.defs : DrawEventType, NetEventType;

struct Engine {

	EventManager renderer_evman_ = void;
	IRenderer renderer_;

	EventManager network_evman_ = void;
	NetworkPeer network_ = void;

	@disable this();
	@disable this(this);

	void initialize() {

		//initialize renderer and event manager for rendering events
		this.renderer_evman_ = EventManager(EventMemory, DrawEventType.max);
		this.renderer_ = new OpenGLRenderer();

		//initialize network system and event manager for communication
		this.network_evman_ = EventManager(EventMemory, NetEventType.max);
		this.network_ = NetworkPeer(12000, &network_evman_);

	} //initialize

} //Engine