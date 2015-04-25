module blindfire.action;

import blindfire.engine.window : Window;
import blindfire.engine.stream : InputStream, OutputStream;
import blindfire.engine.defs : Vec2f;

import blindfire.serialize : networked;
import blindfire.ui : UIState, draw_rectangle;
import blindfire.netgame : Action, ActionType;
import blindfire.game : Resource;
import blindfire.sys;

import profan.ecs;

enum : ActionType[string] {

	ActionIdentifier = [
		NoAction.stringof : 0,
		MoveAction.stringof : 1,
		CreateUnitAction.stringof : 2
	]

}

class NoAction : Action {

	mixin DoSerializable!();

	void execute(EntityManager em) {

	}

} //NoAction

import blindfire.serialize : DoSerializable, MakeTypeSerializable;
import profan.collections : StaticArray;

class MoveAction : Action {

	@networked EntityID entity;
	@networked Vec2f position;

	mixin DoSerializable!();

	this() {

	}

	this(EntityID entity, Vec2f pos) {
		this.entity = entity;
		this.position = pos;
	}

	void execute(EntityManager em) {
		em.get_component!(SelectionComponent)(entity).set_target(position);
	}

} //MoveAction

class CreateUnitAction : Action {

	import blindfire.engine.resource : ResourceManager;
	import blindfire.ents : create_unit;

	@networked Vec2f position;

	mixin DoSerializable!();

	this() {

	}

	this(Vec2f position) {
		this.position = position;
	}

	void execute(EntityManager em) {
		auto rm = ResourceManager.get();
		create_unit(em, position, 
					rm.get_resource!Shader(Resource.BASIC_SHADER), 
					rm.get_resource!Texture(Resource.UNIT_TEXTURE));
	}

} //CreateUnitAction

struct SelectionBox {

	bool active = false, order_set = false;
	int x = 0, y = 0;
	int w = 0, h = 0;
	int to_x = 0, to_y = 0;
	
	void set_order(int new_x, int new_y) {
		order_set = true;
		to_x = new_x;
		to_y = new_y;
	}

	void set_size(int new_w, int new_h) {
		w = new_w - x;
		h = new_h - y;
	}

	void set_active(int start_x, int start_y) {
		x = start_x;
		y = start_y;
		w = 0; h = 0;
		active = true;
	}

	void set_inactive(int x, int y) {
		w = 0;
		h = 0;
		active = false;
	}

	void draw(Window* window, UIState* state) {

		if (active) {
			state.draw_rectangle(window, x, y, w, h, 0x842bca, 30);
		}
		
		order_set = false;

	}

} //SelectionBox
