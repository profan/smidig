module blindfire.ents;

import std.stdio : writefln;

import blindfire.engine.gl : Mesh, Shader, Texture, Transform, Vertex, create_rectangle_vec3f2f;
import blindfire.engine.defs : Vec2f, Vec3f;

import blindfire.sys;
import profan.ecs;

auto create_wall(EntityManager em, Vec2f pos, Vec2f bottom_right, Shader* shader, Texture* texture) {

}

auto create_unit(EntityManager em, Vec2f pos, Shader* shader, Texture* texture) {

	assert (em !is null);
	auto unit = em.create_entity();

	TransformComponent mc = {velocity: Vec2f(0, 0), transform: Transform(pos)};
	mc.transform.origin = Vec3f(-texture.width/2, -texture.height/2, 0.0f);
	em.register_component!TransformComponent(unit, mc);

	em.register_component!CollisionComponent(unit); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(unit);
	cc.radius = texture.width/2; //arbitrary number :D

	em.register_component!InputComponent(unit);
	em.register_component!SelectionComponent(unit);
	em.register_component!OrderComponent(unit);

	em.register_component!SpriteComponent(unit);
	SpriteComponent* sc = em.get_component!SpriteComponent(unit);
	
	int w = texture.width;
	int h = texture.height;
	Vertex[6] vertices = create_rectangle_vec3f2f(w, h);
	sc.mesh = Mesh(vertices.ptr, vertices.length);
	sc.texture = texture;
	sc.shader = shader;
	
	return unit;

}
