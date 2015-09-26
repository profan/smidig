module blindfire.ents;

import std.stdio : writefln;

import blindfire.engine.gl : Mesh, Shader, Texture, Transform, Vertex, create_rectangle_vec3f2f;
import blindfire.engine.defs : Vec2f, Vec3f;
import blindfire.engine.ecs;

import blindfire.sys;

auto create_wall(EntityManager em, Vec2f pos, Vec2f bottom_right, Shader* shader, Texture* texture) {

}

auto create_unit(EntityManager em, Vec2f pos, Shader* shader, Texture* texture) {

	assert (em !is null);
	auto unit = em.createEntity();

	TransformComponent mc = {velocity: Vec2f(0, 0), transform: Transform(pos)};
	mc.transform.origin = Vec3f(-texture.width/2, -texture.height/2, 0.0f);
	em.register!TransformComponent(unit, mc);

	em.register!CollisionComponent(unit); //beware of order, this depends on above component
	auto cc = em.getComponent!CollisionComponent(unit);
	cc.radius = texture.width/2; //arbitrary number :D

	em.register!InputComponent(unit);
	em.register!SelectionComponent(unit);
	em.register!OrderComponent(unit);

	em.register!SpriteComponent(unit);
	SpriteComponent* sc = em.getComponent!SpriteComponent(unit);
	
	int w = texture.width;
	int h = texture.height;
	Vertex[6] vertices = create_rectangle_vec3f2f(w, h);
	sc.mesh = Mesh(vertices);
	sc.texture = texture;
	sc.shader = shader;
	
	return unit;

}
