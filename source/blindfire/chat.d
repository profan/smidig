module blindfire.chat;

import core.stdc.stdio : printf;

struct Chat {

	import derelict.enet.enet;

	import blindfire.engine.defs : ConnectionEvent, DisconnectionEvent, UpdateEvent, PushEvent;
	import blindfire.engine.collections : Array, StringBuffer, StaticArray;
	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.event : EventManager;
	import blindfire.engine.util : cformat;

	struct Client {

		ENetPeer* peer;

	} //Client

	private {

		IAllocator allocator_;

		EventManager* ev_man_;
		StringBuffer buffer_;

		//chat data
		Array!Client clients_;

		//input the texts
		StaticArray!(char, 256) input_buffer_;

	}

	@disable this();
	@disable this(this);

	this(IAllocator allocator, EventManager* ev_man) {

		this.allocator_ = allocator;
		this.ev_man_ = ev_man;
		this.buffer_ = typeof(buffer_)(256);
		this.clients_ = typeof(clients_)(allocator_, 16);

	} //this

	void onPeerConnect(ref ConnectionEvent cev) {

		char[512] buff;
		buffer_ ~= cformat(buff, "connection from: %x:%u \n", cev.payload.address.host, cev.payload.address.port);

		clients_ ~= Client(cev.payload);

	} //onPeerConnect

	void onPeerDisconnect(ref DisconnectionEvent dev) {

		char[512] buff;
		buffer_ ~= cformat(buff, "disconnection from: %x:%u \n", dev.payload.address.host, dev.payload.address.port);

		auto to_remove = Client(dev.payload);
		clients_.remove(to_remove);

	} //onPeerDisconnect

	void on_network_update(ref UpdateEvent ev) {

		char[512] buff;
		auto peer = ev.payload.peer;
		auto data = ev.payload.data;
		buffer_ ~= cformat(buff, "%x:%u > %s \n", peer.address.host, peer.address.port, cast(char*)data.ptr);

	} //on_receive

	void tick() {

		import derelict.imgui.imgui;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Chat");

		if (igTreeNodeStr("clients", "clients (%d)", clients_.length)) {
			foreach (ref c; clients_) {
				igText("%x:%u", c.peer.address.host, c.peer.address.port);
			}
			igTreePop();
		}

		igText(buffer_.c_str);

		igInputText("input: ", input_buffer_.ptr, input_buffer_.capacity);
		auto did_submit = igButton("send");

		//user wants to send shit?
		if (did_submit) {
			input_buffer_.scan_to_null();
			ev_man_.fire!PushEvent(input_buffer_[]);
			input_buffer_ = input_buffer_.init;
		}

		igEnd();

	} //tick

} //Chat