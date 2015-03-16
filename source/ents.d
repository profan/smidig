module sundownstandoff.ents;

import profan.ecs;

import sundownstandoff.sys;

auto create_player(EntityManager em, Vec2f pos) {

	auto player = em.create_entity();

	MovementComponent mc = {velocity: Vec2f(0,0), position: pos};
	em.register_component!MovementComponent(player, mc);
	em.register_component!CollisionComponent(player); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(player);
	cc.radius = 32; //arbitrary number :D
	em.register_component!InputComponent(player);
	em.register_component!SpriteComponent(player);

	return player;

}
