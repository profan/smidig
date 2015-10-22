module blindfire.engine.joy;

struct JoyVisualizer {

	import blindfire.engine.input : InputHandler;

	this(InputHandler* handler) {

		import derelict.sdl2.types;

		handler
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_LEFTX, &left_x)
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_LEFTY, &left_y)
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_RIGHTX, &right_x)
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_RIGHTY, &right_y)
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_TRIGGERLEFT, &trigger_left)
			.bind_controlleraxis(SDL_CONTROLLER_AXIS_TRIGGERRIGHT, &trigger_right);

	} //this

	int l_x;
	void left_x(int i) {
		l_x = i;
	} //left_x

	int l_y;
	void left_y(int i) {
		l_y = i;
	} //left_y

	int r_x;
	void right_x(int i) {
		r_x = i;
	} //right_x

	int r_y;
	void right_y(int i) {
		r_y = i;
	} //right_y

	int t_l;
	void trigger_left(int i) {
		t_l = i;
	} //trigger_left

	int t_r;
	void trigger_right(int i) {
		t_r = i;
	} //trigger_right

	void tick() {

		import derelict.imgui.imgui;

		igBegin("Gamepad Axis Test");

		igSliderInt("left x:", &l_x, -32768, 32768);
		igSliderInt("left y:", &l_y, -32768, 32768);

		igSliderInt("right x:", &r_x, -32768, 32768);
		igSliderInt("right y:", &r_y, -32768, 32768);

		igSliderInt("trigger left:", &t_l, -32768, 32768);
		igSliderInt("trigger right:", &t_r, -32768, 32768);

		igEnd();

	} //tick

} //JoyVisualizer