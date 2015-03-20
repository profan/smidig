module sundownstandoff.sys;

import std.concurrency : send, Tid;

import gl3n.linalg;

import profan.ecs;

alias Vec2f = Vector!(float, 2);
alias Mat3f = Matrix!(float, 3, 3);

class MovementManager : ComponentManager!(MovementComponent, 3) {

	override void update() {

		foreach (id, ref comp; components) {
			comp.position += comp.velocity;
		}

	}

} //MovementManager

struct MovementComponent {

	Vec2f velocity;
	Vec2f position;
	Mat3f transform;

} //MovementComponent

class CollisionManager : ComponentManager!(CollisionComponent, 2) {

	override void update() {

		foreach (id, ref comp; components) {
			//check collisions, do callback
		}

	}

} //CollisionManager

struct CollisionComponent {

	double radius;
	void delegate(EntityID) on_collision;
	@dependency MovementComponent* mc;

} //CollisionComponent

class InputManager : ComponentManager!(InputComponent, 1) {

	override void update() {

		foreach (id, ref comp; components) {
			//DO ALL THE CALLBACKS
		}

	}

} //InputManager

struct InputComponent {

	//.. callbacks?

} //InputComponent

class NetworkManager : ComponentManager!(NetworkComponent) {

	Tid network_thread;

	this(Tid net_thread) {

		this.network_thread = net_thread;

	}

	override void update() {

		foreach (id, ref comp; components) {
			//package everything, send to other player!
		}

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism

} //NetworkComponent

class SpriteManager : ComponentManager!(SpriteComponent, 4) {

	import sundownstandoff.ui : draw_rectangle, DrawFlags;
	import sundownstandoff.window : Window;

	Window* window;

	this(Window* window) {
		this.window = window;
	}

	override void update() {

		foreach (id, ref comp; components) {
			draw_rectangle(window, DrawFlags.FILL, cast(int)comp.mc.position.x, cast(int)comp.mc.position.y, comp.w, comp.h, comp.color);
		}

	}

} //SpriteManager

struct SpriteComponent {

	//some drawing stuff?
	//texture and vao?
	int w, h;
	int color;
	@dependency MovementComponent* mc;

} //SpriteComponent

class OrderManager : ComponentManager!(OrderComponent, 5) {

	override void update() {

		foreach (id, ref comp; components) {

		}

	}

} //OrderManager

struct OrderComponent {

	Order[10] orders;

} //OrderComponent

struct Order {

	//enum value and some data?

} //Order
