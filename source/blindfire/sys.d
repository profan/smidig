module blindfire.sys;

import std.math : cos, sin, PI, pow;
import std.stdio : writefln;

import blindfire.engine.window : Window;
import blindfire.engine.math : rotate, squaredDistanceTo;
import blindfire.engine.gl : Transform, Shader, Texture, Mesh;
import blindfire.engine.math : Vec2i, Vec2f, Vec3f, Mat3f;
import blindfire.engine.stream : InputStream;
import blindfire.engine.math : pointInRect;
import blindfire.engine.ecs;

import blindfire.action;

interface UpdateSystem : ComponentSystem!(0) {

	void update();

} //UpdateSystem

interface DrawSystem : ComponentSystem!(1) {

	void update(Window* window);

} //DrawSystem

class TransformManager : ComponentManager!(UpdateSystem, TransformComponent, 3) {

	import blindfire.defs;
	import blindfire.engine.math;

	void onAnalogMovement(ref AnalogAxisEvent ev) {

		enum offset = deg2Rad(-135);

		float value = cast(float)ev.value;
		float normalized = normalize!float(value, 0.0f, 1.0f, 32768.0f);

		auto cmp = ev.id in components;
		cmp.velocity += (angleToVec2!float(cmp.transform.rotation.z + offset) * normalized);

	} //onAnalogMovement

	void onAnalogRotation(ref AnalogRotEvent ev) {

		float value = cast(float)ev.value;
		float normalized = normalize(value, -1.0f, 1.0f, 32768.0f);

		auto cmp = ev.id in components;
		cmp.transform.rotation.z += normalized/10;

	} //onAnalogRotation

	override void onInit(EntityID entity, TransformComponent* component) {

	} //onInit

	void update() {

		import derelict.imgui.imgui;

		foreach (id, ref comp; components) with (comp) {
			transform.position += velocity;
			velocity /= 1.05;
		}

	} //update

} //TransformManager

struct TransformComponent {

	Vec2f velocity;
	Transform transform;

} //TransformComponent

class CollisionManager : ComponentManager!(UpdateSystem, CollisionComponent, 2) {

	Vec2i map_size;

	this(Vec2i size) {
		this.map_size = size;
	}

	void update() {

		foreach (id, ref comp; components) {

			with (comp.mc.transform) {
				if (!pointInRect(cast(int)position.x, cast(int)position.y, 0, 0, map_size.x, map_size.y)) {
					comp.mc.velocity = Vec2f(-comp.mc.velocity.x, -comp.mc.velocity.y);
					comp.mc.transform.rotation.z += 1*PI;
				}
			}

			foreach (other_id, ref other_comp; components) {
				if (id == other_id) continue;

				if (comp.mc.transform.position.squaredDistanceTo(other_comp.mc.transform.position) < pow((comp.radius + other_comp.radius), 2)) {
					comp.mc.velocity = Vec2f(-comp.mc.velocity.x, -comp.mc.velocity.y);
				}

			}
		}

	} //update

} //CollisionManager

struct CollisionComponent {

	double radius;
	void delegate(EntityID) on_collision;
	@dependency TransformComponent* mc;

} //CollisionComponent

class SpriteManager : ComponentManager!(DrawSystem, SpriteComponent, 4) {

	void update(Window* window) {

		foreach (id, ref comp; components) with (comp) {
			shader.bind();
			texture.bind(0);
			shader.update(window.view_projection, tc.transform);
			mesh.draw();
			texture.unbind();
			shader.unbind();
		}

	} //update

} //SpriteManager

struct SpriteComponent {

	Mesh mesh;
	Shader* shader;
   	Texture* texture;
	@dependency TransformComponent* tc;

	this(ref Mesh in_mesh, Shader* shader, Texture* texture) {

		import std.algorithm : move;

		move(in_mesh, this.mesh);
		this.shader = shader;
		this.texture = texture;

	} //this

} //SpriteComponent

