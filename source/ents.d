module sundownstandoff.ents;

import profan.ecs;

import sundownstandoff.sys;

auto create_player(EntityManager em, Vec2f position) {

	auto player = em.create_entity();

	em.register_component!MovementComponent(player);
	em.register_component!CollisionComponent(player); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(player);
	cc.radius = 32; //arbitrary number :D

	return player;

}
