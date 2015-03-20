module sundownstandoff.ents;

import profan.ecs;

import sundownstandoff.sys;

auto create_unit(EntityManager em, Vec2f pos) {

	auto unit = em.create_entity();

	MovementComponent mc = {velocity: Vec2f(0,0), position: pos};
	em.register_component!MovementComponent(unit, mc);
	em.register_component!CollisionComponent(unit); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(unit);
	cc.radius = 32; //arbitrary number :D
	em.register_component!InputComponent(unit);
	em.register_component!SpriteComponent(unit);
	SpriteComponent* sc = em.get_component!SpriteComponent(unit);
	sc.color = 0xffa500;
	sc.w = 32;
	sc.h = 32;

	return unit;

}
