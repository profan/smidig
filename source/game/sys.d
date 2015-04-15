module blindfire.sys;

import std.concurrency : send, receiveTimeout, Tid;
import std.stdio : writefln;
import profan.ecs;

import blindfire.engine.window : Window;
import blindfire.engine.gl : Vec2f, Mat3f, Transform, Shader, Texture, Mesh;
import blindfire.engine.net : NetVar, Command, ClientID;
import blindfire.engine.stream : InputStream;

import blindfire.serialize : networked;
import blindfire.ents : IsRemote;

alias ComponentType = uint;
enum : ComponentType[string] {
	ComponentIdentifier = [
		TransformComponent.stringof : 0
	]
}

mixin template NetIdentifier() {
	@networked NetVar!(uint) identifier = ComponentIdentifier[typeof(this).stringof];
}

interface UpdateSystem : ComponentSystem!(0) {

	void update();

}

interface DrawSystem : ComponentSystem!(1) {

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

	mixin NetIdentifier;
	@networked NetVar!(Vec2f) velocity;
	@networked NetVar!(Transform) transform;

} //TransformComponent

class CollisionManager : ComponentManager!(UpdateSystem, CollisionComponent, 2) {

	void update() {

		foreach (ref id, ref comp; components) {
			foreach (ref other_id, ref other_comp; components) {
				if (id == other_id) continue;

				if (comp.mc.transform.position.distanceTo(other_comp.mc.transform.position) < (comp.radius + other_comp.radius)) {
					comp.mc.velocity = Vec2f(-comp.mc.velocity.x, -comp.mc.velocity.y);
				}

			}
		}

	}

} //CollisionManager

struct CollisionComponent {

	double radius;
	void delegate(EntityID) on_collision;
	@dependency() TransformComponent* mc;

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
	import blindfire.serialize : serialize, deserialize, DeSerializeMembers;
	import blindfire.netmsg : UpdateType, EntityType;
	import blindfire.ents : create_unit;
	import blindfire.game : Resource;

	Tid network_thread;

	//reused buffer for sending data
	enum MAX_PACKET_SIZE = 65536; //bytes
	StaticArray!(ubyte, MAX_PACKET_SIZE) recv_data;
	StaticArray!(ubyte, MAX_PACKET_SIZE) send_data;

	this(Tid net_thread) {
		this.network_thread = net_thread;
	}

	void update() {

		receiveTimeout(dur!("nsecs")(1),
		(Command cmd, immutable(ubyte)[] data) {

			bool done = false;
			auto input_stream = InputStream(cast(ubyte*)data.ptr, data.length);

			writefln("[GAME] Received world update, %d bytes", data.length);
			UpdateType type = input_stream.read!UpdateType();

			while (!done && input_stream.current < data.length) {

				switch (type) {

					case UpdateType.CREATE:

						EntityID entity_id = input_stream.read!EntityID();
						EntityType entity_type = input_stream.read!EntityType();

						switch (entity_type) {
							case EntityType.UNIT: //create_unit

								import blindfire.engine.resource : ResourceManager;

								Vec2f position = input_stream.read!Vec2f();
								create_unit!(IsRemote.Yes)(em, position, &entity_id, 
										ResourceManager.get().get_resource!(Shader)(Resource.BASIC_SHADER),
										ResourceManager.get().get_resource!(Texture)(Resource.UNIT_TEXTURE));
								break;

							default:
								writefln("[GAME] [C] Unhandled Entity from %s, id: %d", entity_id.owner, entity_type);
						}

						break;

					case UpdateType.DESTROY:

						EntityID entity_id = input_stream.read!EntityID();
						em.unregister_component(entity_id);
						
						break;

					case UpdateType.UPDATE:
							
						EntityID entity_id = input_stream.read!EntityID();
						ubyte num_components = input_stream.read!ubyte();

						for (uint i = 0; i < num_components; ++i) {

							ComponentType component_type = input_stream.read!ComponentType();

							switch (component_type) {
								case ComponentIdentifier[TransformComponent.stringof]:
									deserialize!TransformComponent(input_stream, components[entity_id].tc);
									break;

								default:
									writefln("[GAME] Unhandled Component from %s, id: %d", entity_id.owner, component_type);
									done = true; //all bets are off at this point
							}

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

			ubyte num_components = 1;
			if (comp.local == IsRemote.No) {

				//write which entity it belongs to
				send_data ~= (cast(ubyte*)&id)[0..id.sizeof];
				send_data ~= (cast(ubyte*)&num_components)[0..num_components.sizeof];

				//write the fields to be serialized in the entity's components.
				serialize(send_data, comp.tc);

			}

		}

		writefln("[GAME] Sending %d bytes to NET", send_data.elements);

		//make a version which uses double buffers or something and never allocs
		//currently takes a slice of the internal array to as far as the buffer was actually filled
		send(network_thread, Command.UPDATE, send_data[0..send_data.elements].idup);

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism
	IsRemote local = IsRemote.No;
	@dependency() @networked TransformComponent* tc;


} //NetworkComponent

class SpriteManager : ComponentManager!(DrawSystem, SpriteComponent, 4) {

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

	import blindfire.engine.gl : Mesh, Shader, Texture;

	//some drawing stuff?
	//texture and vao?
	Mesh mesh;
	Shader* shader;
   	Texture* texture;
	@dependency() TransformComponent* tc;

} //SpriteComponent

class OrderManager : ComponentManager!(UpdateSystem, OrderComponent, 5) {

	import blindfire.engine.util : point_in_rect;
	import blindfire.action : SelectionBox;
	import std.math : atan2;

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
	@dependency() TransformComponent* tc;
	Order[10] orders;

} //OrderComponent

struct Order {

	//enum value and some data?

} //Order
