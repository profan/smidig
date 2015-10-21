module blindfire.engine.net;

struct NetVar(T) {

	alias variable this;
	bool changed = false;
	
	union {
		T variable;
		ubyte[T.sizeof] bytes;
	}

	this(T var) {
		this.variable = var;
	} //this

	T opUnary(string op)() if (s == "++" || s == "--") {
		changed = true;
		mixin("return " ~ op ~ " variable;");
	} //opUnary

	void opAssign(T rhs) {
		changed = true;
		variable = rhs;
	} //opAssign

	void opOpAssign(string op)(T rhs) {
		changed = true;
		mixin("variable " ~ op ~ "= rhs;");
	} //opOpAssign

	T opBinary(string op)(T rhs) {
		mixin("return variable " ~ op ~ " rhs;");
	} //opBinary

} //NetVar

void initialize_enet() {

	import core.stdc.stdio : printf;
	import derelict.enet.enet;

	if (auto err = enet_initialize() != 0) {

		printf("[Net] An error occured on initialization: %d", err);

	}

} //initialize_enet

struct NetworkManager {

	import core.stdc.stdio : printf;
	import derelict.enet.enet;

	import blindfire.engine.event : EventManager;
	import blindfire.engine.collections : Array;
	import blindfire.engine.memory : IAllocator;
	import blindfire.engine.defs : ConnectionEvent, DisconnectionEvent, UpdateEvent, PushEvent, Update;

	enum num_channels = 2;

	private {

		EventManager* ev_man_;

		ENetHost* host_;
		Array!(ENetPeer*) peers_;

		bool connected_;
		bool is_host_;

	}

	@property bool is_active() { return connected_; }
	@property bool is_host() { return is_host_; }

	@disable this();
	@disable this(this);

	this(IAllocator allocator, EventManager* ev_man) {

		this.ev_man_ = ev_man;
		this.peers_ = typeof(peers_)(allocator, 1);

	} //this

	~this() {

		if (host_) {
			printf("[Net] destroyed server. \n");
			enet_host_destroy(host_);
		}

	} //~this

	void initialize() {

	} //initialize

	bool create_server(ushort binding_port, ubyte max_connections) {

		assert(!host_, "host was not null on create server!");

		ENetAddress address;
		address.host = ENET_HOST_ANY;
		address.port = binding_port;

		host_ = enet_host_create(&address,
								max_connections,
								num_channels, /* number of data channels */
								0, /* max incoming */
								0); /* max outgoing */

		this.peers_.reserve(max_connections);

		if (!host_) {
			printf("[Net] failed creating server! \n");
			return false;
		} else {
			printf("[Net] created server at %s:%u \n", cast(const(char*))"localhost".ptr, binding_port);
		}

		is_host_ = true;
		connected_ = true;

		return true;

	} //create_server

	bool create_client(char* to_address, ushort port) {

		if (!host_) {

			host_ = enet_host_create(null,
									1,
									num_channels,
									0,
									0);

			if (!host_) {
				printf("[Net] failed creating client! \n");
				return false;
			}

		}
		
		ENetAddress address;
		enet_address_set_host(&address, to_address);
		address.port = port;

		ENetPeer* new_peer = enet_host_connect(host_, &address, num_channels, 0);

		if (!new_peer) {
			printf("[Net] no available peers for initiating an ENet connection. \n");
			return false;
		} else {
			peers_ ~= new_peer;
		}

		ENetEvent event;
		if (enet_host_service(host_, &event, 5000) > 0 &&
			event.type == ENET_EVENT_TYPE_CONNECT)
		{
			printf("[Net] connection to %s:%u succeeded. \n", to_address, port);
			ev_man_.push!ConnectionEvent(new_peer);
		} else {
			printf("[Net] connection to %s:%u failed. \n", to_address, port);
			return false;
		}

		connected_ = true;

		return true;

	} //create_client

	void disconnect() {

		foreach (peer; peers_) {
			enet_peer_disconnect(peer, 0);
		}

		peers_.clear();
		connected_ = false;

	} //disconnect

	void on_data_push(ref PushEvent ev) {

		printf("[Net] sending packet of size: %u \n", typeof(ev.payload[0]).sizeof * ev.payload.length);
		ENetPacket* packet = enet_packet_create(ev.payload.ptr, ev.payload.length, ENET_PACKET_FLAG_RELIABLE);

		foreach (peer; peers_) {
			enet_peer_send(peer, 0, packet);
		}

	} //on_data_push

	void poll() {

		if (!host_) return;

		ENetEvent event;
		while (enet_host_service(host_, &event, 0) > 0) {

			final switch (event.type) {

				case ENET_EVENT_TYPE_CONNECT:
					printf("[Net] new connection from %x:%u.\n", 
						   event.peer.address.host,
						   event.peer.address.port);

					peers_ ~= event.peer;
					ev_man_.push!ConnectionEvent(event.peer);

					break;

				case ENET_EVENT_TYPE_RECEIVE:
					printf("A packet of length %u was received from %s on channel %u.\n",
							event.packet.dataLength,
							event.peer.data,
							event.channelID);

					ev_man_.fire!UpdateEvent(Update(event.peer, event.packet.data[0..event.packet.dataLength]));

					/* Clean up the packet now that we're done using it. */
					enet_packet_destroy (event.packet);

					break;

				case ENET_EVENT_TYPE_DISCONNECT:
					printf("[Net] %x:%u disconnected. \n", 
						   event.peer.address.host,
						   event.peer.address.port);

					peers_.remove(event.peer);
					ev_man_.push!DisconnectionEvent(event.peer);

					event.peer.data = null;
					break;

			}

		}

	} //poll

	void draw() {

		import derelict.imgui.imgui;

		static bool show_another_window;
		static int host_port = 12300;

		igSetNextWindowSize(ImVec2(200, 100), ImGuiSetCond_FirstUseEver);
		igBegin("Network Manager", &show_another_window);

		{

			if (!is_active) {

				auto do_server = igButton("Create Server.");
				auto do_connect = igButton("Connect to Server.");
				igInputInt("port: ", &host_port);

				if (do_server) {
					create_server(cast(ushort)host_port, cast(ubyte)32);
				}

				if (do_connect) {
					create_client(cast(char*)"localhost".ptr, cast(ushort)host_port);
				}

			} else if (!is_host) {

				auto do_disconnect = igButton("Disconnect from Server.");

				if (do_disconnect) {
					disconnect();
				}

			}

			if (is_active) {
				igValueBool("is host: ", is_host);
			}

		}

		igEnd();

	} //draw

} //NetworkManager

struct NetworkServer {

} //NetworkServer

struct NetworkClient {

} //NetworkClient