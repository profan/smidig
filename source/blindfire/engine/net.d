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
	}

	T opUnary(string op)() if (s == "++" || s == "--") {
		changed = true;
		mixin("return " ~ op ~ " variable;");
	}

	void opAssign(T rhs) {
		changed = true;
		variable = rhs;
	}

	void opOpAssign(string op)(T rhs) {
		changed = true;
		mixin("variable " ~ op ~ "= rhs;");
	}

	T opBinary(string op)(T rhs) {
		mixin("return variable " ~ op ~ " rhs;");
	}

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
	import blindfire.engine.defs : ConnectionEvent, DisconnectionEvent, UpdateEvent, PushEvent, Update;

	enum num_channels = 2;

	private {

		EventManager* ev_man_;

		ENetHost* host_;
		ENetPeer* peer_;
		bool is_host_;
		bool connected_;

	}

	@property bool is_active() { return connected_; }
	@property bool is_host() { return is_host_; }

	@disable this();
	@disable this(this);

	this(EventManager* ev_man) {

		this.ev_man_ = ev_man;

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

		if (!host_) {
			printf("[Net] failed creating server! \n");
			return false;
		} else {
			printf("[Net] created server at %s:%u \n", cast(char*)"localhost".ptr, binding_port);
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

		peer_ = enet_host_connect(host_, &address, num_channels, 0);

		if (!peer_) {
			printf("[Net] no available peers for initiating an ENet connection. \n");
			return false;
		}

		ENetEvent event;
		if (enet_host_service(host_, &event, 5000) > 0 &&
			event.type == ENET_EVENT_TYPE_CONNECT) 
		{
			printf("[Net] connection to %s:%u succeeded. \n", to_address, port);
		} else {
			printf("[Net] connection to %s:%u failed. \n", to_address, port);
			return false;
		}

		connected_ = true;

		return true;

	} //create_client

	void disconnect() {
		enet_peer_disconnect(peer_, 0);
		connected_ = false;
	} //disconnect

	void on_data_push(ref PushEvent ev) {

		printf("[Net] sending packet of size: %u \n", typeof(ev.payload).sizeof * ev.payload.length);
		ENetPacket* packet = enet_packet_create(ev.payload.ptr, ev.payload.length, ENET_PACKET_FLAG_RELIABLE);
		enet_peer_send(peer_, 0, packet);

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

					ev_man_.push!ConnectionEvent(event.peer);

					break;

				case ENET_EVENT_TYPE_RECEIVE:
					printf("A packet of length %u containing %s was received from %s on channel %u.\n",
							event.packet.dataLength,
							event.packet.data,
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

					ev_man_.push!DisconnectionEvent(event.peer);

					event.peer.data = null;
					break;

			}

		}

	} //poll

} //NetworkManager

struct NetworkServer {

} //NetworkServer

struct NetworkClient {

} //NetworkClient