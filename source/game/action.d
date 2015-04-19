module blindfire.action;

import blindfire.engine.window : Window;
import blindfire.engine.defs : Vec2f;

import blindfire.ui : UIState, draw_rectangle;
import blindfire.netgame : Action;
import blindfire.sys;

import profan.ecs;

class MoveAction : Action {

	EntityID entity;
	Vec2f position;

	this(EntityID entity, Vec2f pos) {
		this.entity = entity;
		this.position = pos;
	}

	void execute(EntityManager em) {
		em.get_component!(SelectionComponent)(entity).set_target(position);
	}

} //MoveAction

struct SelectionBox {

	bool active = false, order_set = false;
	int x = 0, y = 0;
	int w = 0, h = 0;
	int to_x = 0, to_y = 0;
	
	EntityManager em;

	this(EntityManager em) {
		this.em = em;
	}

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
			state.draw_rectangle(window, x, y, w, h, 0x428bca, 30);
		}
		
		order_set = false;

	}

} //SelectionBox
