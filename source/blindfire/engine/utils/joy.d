module blindfire.engine.utils.joy;

struct JoyVisualizer {

	import blindfire.engine.input : InputHandler;

	this(InputHandler* handler) {

		import derelict.sdl2.types;

		handler
			.bindControllerAxis(SDL_CONTROLLER_AXIS_LEFTX, &leftX)
			.bindControllerAxis(SDL_CONTROLLER_AXIS_LEFTY, &leftY)
			.bindControllerAxis(SDL_CONTROLLER_AXIS_RIGHTX, &rightX)
			.bindControllerAxis(SDL_CONTROLLER_AXIS_RIGHTY, &rightY)
			.bindControllerAxis(SDL_CONTROLLER_AXIS_TRIGGERLEFT, &triggerLeft)
			.bindControllerAxis(SDL_CONTROLLER_AXIS_TRIGGERRIGHT, &triggerRight);

	} //this

	int l_x;
	void leftX(int i) {
		l_x = i;
	} //leftX

	int l_y;
	void leftY(int i) {
		l_y = i;
	} //leftY

	int r_x;
	void rightX(int i) {
		r_x = i;
	} //rightX

	int r_y;
	void rightY(int i) {
		r_y = i;
	} //rightY

	int t_l;
	void triggerLeft(int i) {
		t_l = i;
	} //triggerLeft

	int t_r;
	void triggerRight(int i) {
		t_r = i;
	} //triggerRight

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
