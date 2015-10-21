module blindfire.action;

import blindfire.engine.window : Window;
import blindfire.engine.stream : InputStream, OutputStream;
import blindfire.engine.math : Vec2f;
import blindfire.engine.ecs;

import blindfire.serialize : DoSerializable, MakeTypeSerializable, networked;
import blindfire.ui : UIState, draw_rectangle;
import blindfire.res : Resource;
import blindfire.sys;

alias TempBuf = OutputStream;
alias ActionType = uint;

interface Action {

	ActionType identifier() const;
	void serialize(ref TempBuf buf);
	void execute(EntityManager em);

} //Action

string handle_action(alias ActionId)() {

	import std.string : format;

	auto str = "";

	foreach (type, id; ActionId) {
		str ~= format(
				q{case %d:
					auto action = new %s();
					deserialize!(%s)(input_stream, &action);
					action.execute(em);
					break;
				}, id, type, type);
	}

	return str;

} //handle_action

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
