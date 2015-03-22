module sundownstandoff.sys;

import std.concurrency : send, Tid;

import gl3n.linalg;

import profan.ecs;

alias Vec2f = Vector!(float, 2);
alias Mat3f = Matrix!(float, 3, 3);

class TransformManager : ComponentManager!(TransformComponent, 3) {

	override void update() {

		foreach (id, ref comp; components) {

			comp.transform += comp.transform.translation(1.0f, 1.0f, 0.0f);
		}

	}

} //TransformManager

struct TransformComponent {

	import sundownstandoff.net : NetVar;

	NetVar!(Vec2f) velocity;
	NetVar!(Mat3f) transform;

} //TransformComponent

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
	@dependency TransformComponent* mc;

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
			
		}

	}

} //NetworkManager

struct NetworkComponent {

	//things, this kind of thing ought to be more general, wtb polymorphism
	@dependency TransformComponent* mc;
	

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
			draw_rectangle(window, DrawFlags.FILL, cast(int)comp.mc.transform.matrix[0][0], cast(int)comp.mc.transform.matrix[1][1], comp.w, comp.h, comp.color);
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
