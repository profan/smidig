module blindfire.ents;

import std.stdio : writefln;
import std.uuid : UUID;

import blindfire.gl : Vec2f, Transform;
import blindfire.sys;
import profan.ecs;

auto create_unit(bool net = false)(EntityManager em, Vec2f pos, EntityID* id) {

	static if (net) {
		auto unit = em.create_entity(*id);
	} else {
		auto unit = em.create_entity();
	}

	TransformComponent mc = {velocity: Vec2f(0, 0), transform: Transform(pos, Vec2f(0.0f, 0.0f), Vec2f(1.0f, 1.0f))};
	writefln("Matrix: %s", mc.transform);
	em.register_component!TransformComponent(unit, mc);
	em.register_component!CollisionComponent(unit); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(unit);
	cc.radius = 32; //arbitrary number :D
	em.register_component!InputComponent(unit);
	em.register_component!OrderComponent(unit);

	em.register_component!SpriteComponent(unit);
	SpriteComponent* sc = em.get_component!SpriteComponent(unit);
	sc.color = 0xffa500;
	sc.w = 32;
	sc.h = 32;
	
	em.register_component!NetworkComponent(unit);

	static if (net) {
		em.get_component!NetworkComponent(unit).local = false;
	}

	return unit;

}
