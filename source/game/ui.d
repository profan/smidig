module sundownstandoff.ui;

import core.stdc.stdio;
import core.stdc.stdlib;

import derelict.sdl2.sdl;
import derelict.opengl3.gl;

import sundownstandoff.window;
import sundownstandoff.util;

struct PushColor {

	ubyte r, g, b, a;
	GLfloat[4] colors;

	this(ubyte r, ubyte g, ubyte b, ubyte a) {
		glGetFloatv(GL_CURRENT_COLOR, colors.ptr);
		glColor3f(cast(float)(r/255), cast(float)(g/255), cast(float)(b/255));
	}

	~this() {
		glColor3f(colors[0], colors[1], colors[2]);
	}

} //PushColor

struct UIState {

	uint active_item = 0, hot_item = 0;
	int mouse_x, mouse_y;
	uint mouse_buttons;

} //UIState

void before_ui(ref UIState ui) {
	ui.hot_item = 0;
}

void reset_ui(ref UIState ui) {
	if (!is_btn_down(&ui, 1)) {
		ui.active_item = 0;
	} else {
		if (ui.active_item == 0) {
			ui.active_item = -1;
		}
	}
}

enum DrawFlags {

	NONE = 0,
	FILL = 1 << 0,
	BORDER = 1 << 1

} //RectangleType

void set_color(ref GLfloat[4] colors, int color) {
	glGetFloatv(GL_CURRENT_COLOR, colors.ptr);
	glColor3f(cast(float)cast(ubyte)(color>>16)/255, cast(float)cast(ubyte)(color>>8)/255, cast(float)cast(ubyte)(color)/255);
}

void draw_circle(Window* window, DrawFlags flags, int x, int y, int radius, int color, ubyte alpha = 255) {

	import std.math;

	GLfloat[4] colors;
	set_color(colors, color);
	scope(exit) glColor3f(colors[0], colors[1], colors[2]);

	GLenum mode = (flags & flags.FILL) ? GL_TRIANGLE_FAN : GL_LINES;

	glBegin(mode);

	glVertex2f(x, y);
	for(int angle = 1; angle <= 360; angle = angle + 1)
		glVertex2f(x + sin(angle) * radius, y + cos(angle) * radius);

	glEnd();

}

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(Window* window, DrawFlags flags, int x, int y, int width, int height, int color, ubyte alpha = 255) {

	GLfloat[4] colors;
	set_color(colors, color);
	scope(exit) glColor3f(colors[0], colors[1], colors[2]);

	GLenum mode = (flags & flags.FILL) ? GL_TRIANGLES : GL_LINES;

	glBegin(mode);
	
	glVertex3f (x, y, 0); //top left
	glVertex3f (x, y + height, 0); //bottom left
	glVertex3f (x + width, y + height, 0); //bottom right

	glVertex3f (x, y, 0); //top left
	glVertex3f (x + width, y, 0); //top right
	glVertex3f (x + width, y + height, 0); //bottom right

	glEnd();

}

void draw_label(Window* window, SDL_Texture* label, int x, int y, int width, int height) {

	int w, h;
	SDL_QueryTexture(label, null, null, &w, &h);
	SDL_Rect rect = {x: x+width/2-w/2, y: y+height/2-h/2, w: w, h: h};
	//SDL_RenderCopy(window.renderer, label, null, &rect);

}

int darken(int color, uint percentage) {

	uint adjustment = 255 / percentage;
	ubyte r = cast(ubyte)(color>>16), g = cast(ubyte)(color>>8), b = cast(ubyte)(color);
	r -= adjustment;
	g -= adjustment;
	b -= adjustment;
	int result = (r << 16) | (g << 8) | b;
	return result;

}

bool do_button(UIState* ui, uint id, Window* window, bool filled, int x, int y, int width, int height, int color, ubyte alpha = 255, SDL_Texture* label = null) {

	bool result = false;
	bool inside = point_in_rect(ui.mouse_x, ui.mouse_y, x - width/2, y - height/2, width, height);

	if (inside) ui.hot_item = id;

	int m_x = x, m_y = y;
	int main_color = color;
	if (ui.active_item == id && !is_btn_down(ui, 1)) {
		if (inside) {
			result = true;
		} else {
			ui.hot_item = 0;
		}
		ui.active_item = 0;
	} else if (ui.hot_item == id) {
		if (ui.active_item == 0 && is_btn_down(ui, 1)) {
			ui.active_item = id;
		} else if (ui.active_item == id) {
			m_x += 1;
			m_y += 1;
		}
	}

	draw_rectangle(window, (filled) ? DrawFlags.FILL : DrawFlags.NONE, (x - width/2)+2, (y - height/2)+2, width, height, darken(color, 10), alpha);
	draw_rectangle(window, (filled) ? DrawFlags.FILL : DrawFlags.NONE, m_x - width/2, m_y - height/2, width, height, color, alpha);
	if (label != null) draw_label(window, label, m_x - width/2, m_y - height/2, width, height);

	return result;

}

bool is_btn_down(UIState* ui, uint button) {
	return (ui.mouse_buttons >> button-1) & 1;
}
