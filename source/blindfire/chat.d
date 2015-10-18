module blindfire.chat;

import core.stdc.stdio : printf;

struct Chat {

	import derelict.enet.enet;

	import blindfire.engine.defs : ConnectionEvent, DisconnectionEvent, UpdateEvent;
	import blindfire.engine.collections : String;
	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.event : EventManager;
	import blindfire.engine.util : cformat;

	private {

		IAllocator allocator_;

		EventManager* ev_man_;
		String buffer_;

	}

	@disable this(this);

	this(IAllocator allocator, EventManager* ev_man) {

		this.allocator_ = allocator;
		this.ev_man_ = ev_man;
		this.buffer_ = "";

	} //this

	void on_peer_connect(ref ConnectionEvent cev) {
		char[512] buff;
		buffer_ = buffer_ ~ cformat(buff, "connection from: %x:%u \n", cev.payload.address.host, cev.payload.address.port);
	} //on_peer_connect

	void on_peer_disconnect(ref DisconnectionEvent dev) {
		char[512] buff;
		buffer_ = buffer_ ~ cformat(buff, "disconnection from: %x:%u \n", dev.payload.address.host, dev.payload.address.port);
	} //on_peer_disconnect

	void on_network_update(ref UpdateEvent ev) {
		char[512] buff;
		auto peer = ev.payload.peer;
		auto data = ev.payload.data;
		buffer_ = buffer_ ~ cformat(buff, "%x:%u > %s \n", peer.address.host, peer.address.port, data.ptr);
	} //on_receive

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Chat");

		igText(buffer_.c_str);

		igEnd();

	} //tick

} //Chat