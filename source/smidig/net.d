module smidig.net;

struct NetworkManager {

	import core.stdc.stdio : printf;
	import derelict.enet.enet;

	import smidig.event : EventManager;
	import smidig.collections : Array;
	import smidig.memory : IAllocator;
	import smidig.defs : ConnectionEvent, DisconnectionEvent, UpdateEvent, PushEvent, Update;

	enum num_channels = 2; //TODO take a look at this later, maybe allow adjustment?

	private {

		// used for passing data back
		EventManager* ev_man_;

		ENetHost* host_;
		Array!(ENetPeer*) peers_;

		bool connected_;
		bool is_host_;

	}

	@property bool is_active() const { return connected_; }
	@property bool is_host() const { return is_host_; }

	@disable this();
	@disable this(this);

	this(IAllocator allocator, EventManager* ev_man) {

		initialize(); //load libs!

		this.ev_man_ = ev_man;
		this.peers_ = typeof(peers_)(allocator, 1);

	} //this

	~this() {

		if (host_) {
			printf("[Net] destroyed server. \n");
			enet_host_destroy(host_);
		}

	} //~this

	static void initialize() {

		shared static bool is_initialized;
		if (is_initialized) return;

		import gcarena;
		auto ar = useCleanArena();
		DerelictENet.load();

		int err;
		if ((err = enet_initialize()) != 0) {
			printf("[Net] An error occured on initialization: %d", err);
			return;
		}

		is_initialized = true;

	} //initialize

	bool createServer(ushort binding_port, ubyte max_connections) {

		if (host_) return false;

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

	} //createServer

	bool createClient(char* to_address, ushort port) {

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

		ENetEvent event; //TODO move timeout into variable/parameter somewhere
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

	} //createClient

	void disconnect() {

		foreach (peer; peers_) {
			enet_peer_disconnect(peer, 0);
		}

		peers_.clear();
		connected_ = false;

	} //disconnect

	/**
	 * Called whenever an Event containing network data to be sent comes in.
	*/
	void onDataPush(ref PushEvent ev) {

		printf("[Net] sending packet of size: %u \n", typeof(ev.payload[0]).sizeof * ev.payload.length);
		ENetPacket* packet = enet_packet_create(ev.payload.ptr, ev.payload.length, ENET_PACKET_FLAG_RELIABLE);

		foreach (peer; peers_) {
			enet_peer_send(peer, 0, packet);
		}

	} //onDataPush

	/**
	 * Polls ENet for new messages, iterating until all have been processed.
	 * Messages are then forwarded to any receivers through the $(D EventManager) member.
	*/
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
					ev_man_.fire!ConnectionEvent(event.peer);

					break;

				case ENET_EVENT_TYPE_RECEIVE:
					printf("A packet of length %u was received from %s on channel %u.\n",
							event.packet.dataLength,
							event.peer.data,
							event.channelID);

					//TODO take a look at this, should this be handled differently?
					ev_man_.fire!UpdateEvent(Update(event.peer, event.packet.data[0..event.packet.dataLength]));

					/* Clean up the packet now that we're done using it. */
					enet_packet_destroy (event.packet);

					break;

				case ENET_EVENT_TYPE_DISCONNECT:
					printf("[Net] %x:%u disconnected. \n", 
						   event.peer.address.host,
						   event.peer.address.port);

					peers_.remove(event.peer);
					ev_man_.fire!DisconnectionEvent(event.peer);

					event.peer.data = null;
					break;

			}

		}

	} //poll

	/**
	 * Draws a simple ImGui based UI for the server, mainly used for debugging purposes.
	*/
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
					createServer(cast(ushort)host_port, cast(ubyte)32);
				}

				if (do_connect) {
					createClient(cast(char*)"localhost".ptr, cast(ushort)host_port);
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

	mixin NetworkModule;

} //NetworkManager

mixin template NetworkModule() {

	import smidig.defs : NetEventType;
	import smidig.event : EventMemory;
	import smidig.memory : construct;

	enum name = "NetworkModule";
	enum identifier = "input_system_";

	static bool onInit(E)(ref E engine) {

		with (engine) {

			construct(network_evman_, EventMemory, NetEventType.max);
			construct(network_manager_, allocator_, &network_evman_);

		}

		return true;

	} //onInit

	//tick and draw functions, draw already defined here
	alias tick = poll;

	static void linkDependencies(E)(ref E engine) {

		with (engine) {
			network_evman_.register!PushEvent(&network_manager_.onDataPush);
		}

	} //linkDependencies

} //NetworkModule
