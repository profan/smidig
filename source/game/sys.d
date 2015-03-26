module sundownstandoff.sys;

import std.concurrency : send, receiveTimeout, Tid;
import std.stdio : writefln;

import gl3n.linalg;

import profan.ecs;

alias Vec2f = Vector!(float, 2);
alias Mat3f = Matrix!(float, 3, 3);


uint identifier(T: UpdateSystem)() { return 0; }
interface UpdateSystem : ComponentSystem!() {

	void update();

}

uint identifier(T: DrawSystem)() { return 1; }
interface DrawSystem : ComponentSystem!() {

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

	NetVar!(Vec2f) velocity;
	NetVar!(Mat3f) transform;

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

	import profan.collections : StaticArray;

	Tid network_thread;

	//reused buffer for sending data
	StaticArray!(byte, 2048) recv_data;
	StaticArray!(byte, 2048) send_data;

	this(Tid net_thread) {

		this.network_thread = net_thread;

	}

	void update() {

		foreach (id, ref comp; components) {
			
		}

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism
	@dependency TransformComponent* mc;


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
