module sundownstandoff.sys;

import gl3n.linalg;

import profan.ecs;

alias Vec2f = Vector!(float, 2);
alias Mat3f = Matrix!(float, 3, 3);

class MovementManager : ComponentManager!(MovementComponent, 3) {

	//these could be automated somehow, I CAN FEEL IT
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

	//AGAIN
	override CollisionComponent construct_component(EntityID entity) {

		CollisionComponent cc;
		cc.mc = em.get_component!MovementComponent(entity);
		return cc;

	}

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


