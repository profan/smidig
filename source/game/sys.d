module sundownstandoff.sys;

import std.concurrency : send, receiveTimeout, Tid;
import std.stdio : writefln;

import gl3n.linalg;

import profan.ecs;

alias Vec2f = Vector!(float, 2);
alias Mat3f = Matrix!(float, 3, 3);


enum : uint[string] {
	Identifier = [
		"TransformComponent" : 0
	]
}

mixin template NetIdentifier() {
	union {
		uint identifier = Identifier[typeof(this).stringof];
		ubyte[identifier.sizeof] identifier_bytes;
	}	
}

interface UpdateSystem : ComponentSystem!(0) {

	void update();

}

interface DrawSystem : ComponentSystem!(1) {

	import sundownstandoff.window : Window;

	void update(Window* window);

}

class TransformManager : ComponentManager!(UpdateSystem, TransformComponent, 3) {

	void update() {

		foreach (id, ref comp; components) with (comp) {
			transform += transform.translation(velocity.x, velocity.y, 1.0f);
		}

	}

} //TransformManager

struct TransformComponent {

	import sundownstandoff.net : NetVar;
	import sundownstandoff.serialize : networked;

	mixin NetIdentifier;
	@networked NetVar!(Vec2f) velocity;
	@networked NetVar!(Mat3f) transform;

} //TransformComponent

class CollisionManager : ComponentManager!(UpdateSystem, CollisionComponent, 2) {

	void update() {

		foreach (id, ref comp; components) {
			//check collisions, do callback
		}

	}

} //CollisionManager

struct CollisionComponent {

	double radius;
	void delegate(EntityID) on_collision;
	@dependency TransformComponent* mc;

} //CollisionComponent

class InputManager : ComponentManager!(UpdateSystem, InputComponent, 1) {

	void update() {

		foreach (id, ref comp; components) {
			//DO ALL THE CALLBACKS
		}

	}

} //InputManager

struct InputComponent {

	//.. callbacks?

} //InputComponent

class NetworkManager : ComponentManager!(UpdateSystem, NetworkComponent) {


	import std.datetime : dur;
	import profan.collections : StaticArray;
	import sundownstandoff.serialize : serialize;
	import sundownstandoff.net : Command, ClientID;
	import sundownstandoff.netmsg : UpdateType;

	Tid network_thread;
	ClientID client_uuid;

	//reused buffer for sending data
	StaticArray!(ubyte, 2048) recv_data;
	StaticArray!(ubyte, 2048) send_data;

	this(Tid net_thread, ClientID uuid) {
		this.network_thread = net_thread;
		this.client_uuid = uuid;
	}

	void update() {

		receiveTimeout(dur!("nsecs")(1),
		(Command cmd, immutable(ubyte)[] data) {

			bool done = false;
			size_t read_bytes = 0;

			while (!done && read_bytes < data.length) {
				writefln("[GAME] Received world update, %d bytes", data.length);
				UpdateType type = *(cast(UpdateType*)data);
				read_bytes += type.sizeof;

				switch (type) {
					uint component_type = *(cast(uint*)&data[UpdateType.sizeof]);
					EntityID userid = *(cast(EntityID*)&data[uint.sizeof]);
					read_bytes += component_type.sizeof + userid.sizeof;	

					case UpdateType.CREATE:
						break;
					case UpdateType.DESTROY:
						break;
					case UpdateType.UPDATE:		
						switch (component_type) {
							case 0: //TransformComponent
								writefln("[GAME] Handling TransformComponent for id: %s", userid);
								ubyte* ptr = cast(ubyte*)data.ptr;
									
								ptr += Vec2f.sizeof;
								Vec2f vel = *cast(Vec2f*)ptr;
								read_bytes += vel.sizeof;

								ptr += Mat3f.sizeof;
								Mat3f mat = *cast(Mat3f*)ptr;
								read_bytes += mat.sizeof;

								writefln("[GAME] Vector: %s, Matrix: %s", vel, mat);
								components[userid].tc.velocity = vel;
								components[userid].tc.transform = mat;
								break;

							default:
								writefln("[GAME] Unhandled Component, id: %d", type);
								done = true; //all bets are off at this point
						}

						break;

					default:
						writefln("[GAME] Unhandled update type: %s", to!string(type));
						done = true;

				}
			}

		});

		//recieve some stuff, send some stuff
		send_data.elements = 0; //reset point to add to
		//ubyte[UpdateType.sizeof] type = UpdateType.UPDATE;
		UpdateType type = UpdateType.UPDATE;
		send_data ~= (cast(ubyte*)&type)[0..type.sizeof];

		foreach (id, ref comp; components) {
			auto data = serialize(id, comp.tc);
			writefln("[GAME] Data to send: %s", data);
			send_data ~= data;
		}

		//make a version which uses double buffers or something and never allocates
		//currently takes a slice of the internal array to as far as the buffer was actually filled
		send(network_thread, Command.UPDATE, send_data.array[0..send_data.elements].idup);

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism
	@dependency TransformComponent* tc;


} //NetworkComponent

class SpriteManager : ComponentManager!(DrawSystem, SpriteComponent, 4) {

	import sundownstandoff.ui : draw_rectangle, DrawFlags;
	import sundownstandoff.window : Window;

	void update(Window* window) {

		foreach (id, ref comp; components) with (comp) {
			draw_rectangle(window, DrawFlags.FILL, cast(int)mc.transform.matrix[0][2], cast(int)mc.transform.matrix[1][2], w, h, color);
		}

	}

} //SpriteManager

struct SpriteComponent {

	//some drawing stuff?
	//texture and vao?
	int w, h;
	int color;
	@dependency TransformComponent* mc;

} //SpriteComponent

class OrderManager : ComponentManager!(UpdateSystem, OrderComponent, 5) {

	import sundownstandoff.ui : draw_circle, DrawFlags;
	import sundownstandoff.action : SelectionBox;
	import sundownstandoff.util : point_in_rect;

	SelectionBox* sbox;

	this(SelectionBox* sb) {
		this.sbox = sb;
	}

	void update() {

		foreach (id, ref comp; components) with (comp) {
			float x = tc.transform.matrix[0][2];
			float y = tc.transform.matrix[1][2];
			if (sbox.active && point_in_rect(cast(int)x, cast(int)y, sbox.x, sbox.y, sbox.w, sbox.h)) {
				selected = true;
			} else if (sbox.active) {
				selected = false;
			}

			if (comp.selected && sbox.order_set) with (comp.tc) {
				velocity = -(Vec2f(x, y) - Vec2f(sbox.to_x, sbox.to_y)).normalized();
			}

		}

	}

} //OrderManager

struct OrderComponent {

	bool selected = false;
	@dependency TransformComponent* tc;
	Order[10] orders;

} //OrderComponent

struct Order {

	//enum value and some data?

} //Order
