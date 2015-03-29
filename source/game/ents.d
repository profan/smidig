module sundownstandoff.ents;

import std.stdio : writefln;

import profan.ecs;
import gl3n.linalg;
import sundownstandoff.sys;

auto create_unit(bool net = false)(EntityManager em, Vec2f pos) {

	auto unit = em.create_entity();

	TransformComponent mc = {velocity: Vec2f(0, 0), transform: Mat3f(vec3(0, 0, pos.x), vec3(0, 0, pos.y), vec3(0, 0, 1))};
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

	return unit;

}
