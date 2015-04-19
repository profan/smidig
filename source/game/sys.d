module blindfire.sys;

import std.concurrency : send, receiveTimeout, Tid;
import std.stdio : writefln;
import profan.ecs;

import blindfire.engine.window : Window;
import blindfire.engine.gl : Vec2f, Mat3f, Transform, Shader, Texture, Mesh;
import blindfire.engine.net : NetVar, Command, ClientID;
import blindfire.engine.stream : InputStream;

import blindfire.netgame;
import blindfire.action;

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

	Vec2f velocity;
	Transform transform;

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

	Mesh mesh;
	Shader* shader;
   	Texture* texture;
	@dependency TransformComponent* tc;

} //SpriteComponent

class OrderManager : ComponentManager!(UpdateSystem, OrderComponent, 5) {

	import blindfire.engine.util : point_in_rect;

	SelectionBox* sbox;
	TurnManager tm;

	this(SelectionBox* sb, TurnManager tm) {
		this.sbox = sb;
		this.tm = tm;
	}

	//TODO make sure this only works for local units that the player is in control of later, probably easy to fix
	void update() {

		foreach (ref id, ref comp; components) with (comp) {

			float x = tc.transform.position.x;
			float y = tc.transform.position.y;
			if (sbox.active && point_in_rect(cast(int)x, cast(int)y, sbox.x, sbox.y, sbox.w, sbox.h)) {
				selected = true;
			} else if (sbox.active) {
				selected = false;
			}

			if (comp.selected && sbox.order_set) with (comp.tc) {

				//emit order command
				tm.create_action!MoveAction(id, Vec2f(sbox.to_x, sbox.to_y));

			}

		}

	}

} //OrderManager


//TODO order system without polymorphism? hello-switch?
struct OrderComponent {

	bool selected = false;
	@dependency TransformComponent* tc;

} //OrderComponent

class SelectionManager : ComponentManager!(UpdateSystem, SelectionComponent, 6) {

	import std.math : atan2;

	void update() {

		foreach (ref id, ref comp; components) with (comp) {
			
			auto pos = tc.transform.position;
			if (order_set) {
				tc.velocity = -(pos - target_position).normalized();
				tc.transform.rotation.z = atan2(target_position.y - pos.y - 32/2, target_position.x - pos.x-32/2);
				order_set = false;
			}

		}

	}

} //SelectionManager

struct SelectionComponent {

	bool order_set = false;
	Vec2f target_position;
	@dependency TransformComponent* tc;

	void set_target(Vec2f new_pos) {
		target_position = new_pos;
		order_set = true;
	}

} //SelectionComponent
