module blindfire.ents;

import std.stdio : writefln;
import std.uuid : UUID;

import blindfire.engine.gl : Mesh, Shader, Texture, Transform, Vertex;
import blindfire.engine.defs : Vec2f, Vec3f;

import blindfire.sys;
import profan.ecs;

auto create_wall(bool net = false)(EntityManager em, Vec2f pos, Vec2f bottom_right, EntityID* id, Shader* shader, Texture* texture) {

}

auto create_unit(bool net = false)(EntityManager em, Vec2f pos, EntityID* id, Shader* shader, Texture* texture) {

	static if (net) {
		auto unit = em.create_entity(*id);
	} else {
		auto unit = em.create_entity();
	}

	TransformComponent mc = {velocity: Vec2f(0, 0), transform: Transform(pos)};
	mc.transform.origin = Vec3f(-texture.width/2, -texture.height/2, 0.0f);
	em.register_component!TransformComponent(unit, mc);

	em.register_component!CollisionComponent(unit); //beware of order, this depends on above component
	auto cc = em.get_component!CollisionComponent(unit);
	cc.radius = texture.width/2; //arbitrary number :D

	em.register_component!InputComponent(unit);
	em.register_component!OrderComponent(unit);

	em.register_component!SpriteComponent(unit);
	SpriteComponent* sc = em.get_component!SpriteComponent(unit);
	
	int w = texture.width;
	int h = texture.height;
	Vertex[6] vertices = [
		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(w, 0, 0.0), Vec2f(1, 0)), // top right
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)), // bottom right

		Vertex(Vec3f(0, 0, 0.0), Vec2f(0, 0)), // top left
		Vertex(Vec3f(0, h, 0.0), Vec2f(0, 1)), // bottom left
		Vertex(Vec3f(w, h, 0.0), Vec2f(1, 1)) // bottom right
	];

	sc.mesh = Mesh(vertices.ptr, vertices.length);
	sc.texture = texture;
	sc.shader = shader;
	
	em.register_component!NetworkComponent(unit);

	static if (net) {
		em.get_component!NetworkComponent(unit).local = false;
	}

	return unit;

}
