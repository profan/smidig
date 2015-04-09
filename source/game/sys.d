module blindfire.sys;

import std.concurrency : send, receiveTimeout, Tid;
import std.stdio : writefln;

import profan.ecs;
import blindfire.netmsg : ComponentType;

enum : ComponentType[string] {
	Identifier = [
		"TransformComponent" : ComponentType.TRANSFORM_COMPONENT
	]
}

mixin template NetIdentifier() {
	@networked NetVar!(ComponentType) identifier = Identifier[typeof(this).stringof];
}

interface UpdateSystem : ComponentSystem!(0) {

	void update();

}

interface DrawSystem : ComponentSystem!(1) {

	import blindfire.window : Window;

	void update(Window* window);

}

class TransformManager : ComponentManager!(UpdateSystem, TransformComponent, 3) {

	void update() {

		foreach (id, ref comp; components) with (comp) {
			transform.position += velocity;
		}

	}

} //TransformManager

struct TransformComponent {

	import blindfire.net : NetVar;
	import blindfire.serialize : networked;
	import blindfire.gl : Vec2f, Transform;

	mixin NetIdentifier;
	@networked NetVar!(Vec2f) velocity;
	@networked NetVar!(Transform) transform;

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
	import blindfire.serialize : serialize, deserialize;
	import blindfire.net : Command, ClientID;
	import blindfire.netmsg : InputStream, UpdateType, EntityType;
	import blindfire.ents : create_unit;
	import blindfire.gl : Vec2f, Mat3f, Transform;
	import blindfire.game : Resource;

	Tid network_thread;
	ClientID client_uuid;

	//reused buffer for sending data
	enum MAX_PACKET_SIZE = 2048; //bytes
	StaticArray!(ubyte, MAX_PACKET_SIZE) recv_data;
	StaticArray!(ubyte, MAX_PACKET_SIZE) send_data;

	this(Tid net_thread, ClientID uuid) {
		this.network_thread = net_thread;
		this.client_uuid = uuid;
	}

	void update() {

		receiveTimeout(dur!("nsecs")(1),
		(Command cmd, immutable(ubyte)[] data) {

			bool done = false;
			auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

			writefln("[GAME] Received world update, %d bytes", data.length);
			UpdateType type = input_stream.read!UpdateType();
			EntityID entity_id = input_stream.read!EntityID();

			while (!done && input_stream.current < data.length) {

				switch (type) {

					case UpdateType.CREATE:

						EntityType entity_type = input_stream.read!EntityType();

						switch (entity_type) {
							case EntityType.UNIT: //create_unit

								import blindfire.resource : ResourceManager;
								import blindfire.gl : Shader, Texture;

								Vec2f position = input_stream.read!Vec2f();
								create_unit!(true)(em, position, &entity_id, 
										ResourceManager.get().get_resource!(Shader)(Resource.BASIC_SHADER),
										ResourceManager.get().get_resource!(Texture)(Resource.UNIT_TEXTURE));
								break;

							default:
								writefln("[GAME] [C] Unhandled Entity from %s, id: %d", entity_id.owner, entity_type);
						}

						break;

					case UpdateType.DESTROY:

						em.unregister_component(entity_id);
						
						break;

					case UpdateType.UPDATE:

						ComponentType component_type = input_stream.read!ComponentType();

						switch (component_type) {
							case ComponentType.TRANSFORM_COMPONENT: //TransformComponent

								deserialize!TransformComponent(input_stream, components[entity_id].tc);
								break;

							default:
								writefln("[GAME] Unhandled Component from %s, id: %d", entity_id.owner, component_type);
								done = true; //all bets are off at this point
						}

						break;

					default:
						writefln("[GAME] Unhandled update type: %s", to!string(type));
						done = true;

				}
			}

		});

		//handle entity creation and destruction here

		//recieve some stuff, send some stuff
		send_data.elements = 0; //reset point to add to
		UpdateType type = UpdateType.UPDATE;
		send_data ~= (cast(ubyte*)&type)[0..type.sizeof];

		foreach (id, ref comp; components) {

			if (comp.local) {

				//write which entity it belongs to
				send_data ~= (cast(ubyte*)&id)[0..id.sizeof];

				//write the fields to be serialized in the entity's components.
				serialize(send_data, comp.tc);

			}

		}

		writefln("[GAME] Sending %d bytes to NET", send_data.elements);

		//make a version which uses double buffers or something and never allocates
		//currently takes a slice of the internal array to as far as the buffer was actually filled
		send(network_thread, Command.UPDATE, send_data.array[0..send_data.elements].idup);

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism
	bool local = true;
	@dependency TransformComponent* tc;


} //NetworkComponent

class SpriteManager : ComponentManager!(DrawSystem, SpriteComponent, 4) {

	import blindfire.ui : draw_rectangle, DrawFlags;
	import blindfire.window : Window;

	void update(Window* window) {

		foreach (id, ref comp; components) with (comp) {
			shader.bind();
			texture.bind(0);
			shader.update(window.view_projection, tc.transform);
			mesh.draw();
			texture.unbind();
			shader.unbind();
		}

	}

} //SpriteManager

struct SpriteComponent {

	import blindfire.gl : Mesh, Shader, Texture;

	//some drawing stuff?
	//texture and vao?
	Mesh mesh;
	Shader* shader;
   	Texture* texture;
	@dependency TransformComponent* tc;

} //SpriteComponent

class OrderManager : ComponentManager!(UpdateSystem, OrderComponent, 5) {

	import blindfire.ui : draw_circle, DrawFlags;
	import blindfire.action : SelectionBox;
	import blindfire.util : point_in_rect;

	SelectionBox* sbox;

	this(SelectionBox* sb) {
		this.sbox = sb;
	}

	//TODO make sure this only works for local units that the player is in control of later, probably easy to fix
	void update() {

		foreach (id, ref comp; components) with (comp) {
			float x = tc.transform.position.x;
			float y = tc.transform.position.y;
			if (sbox.active && point_in_rect(cast(int)x, cast(int)y, sbox.x, sbox.y, sbox.w, sbox.h)) {
				selected = true;
			} else if (sbox.active) {
				selected = false;
			}

			import std.math;

			if (comp.selected && sbox.order_set) with (comp.tc) {
				velocity = -(Vec2f(x, y) - Vec2f(sbox.to_x, sbox.to_y)).normalized();
				transform.rotation.z = atan2(sbox.to_y - y - 32/2, sbox.to_x - x-32/2);
			}

		}

	}

} //OrderManager


//TODO order system without polymorphism? hello-switch?
struct OrderComponent {

	bool selected = false;
	@dependency TransformComponent* tc;
	Order[10] orders;

} //OrderComponent

struct Order {

	//enum value and some data?

} //Order
