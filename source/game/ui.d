module blindfire.ui;

import core.stdc.stdio;
import core.stdc.stdlib;

import derelict.sdl2.sdl;
import derelict.opengl3.gl;

import blindfire.window;
import blindfire.util;
import blindfire.defs;
import blindfire.text;
import blindfire.gl;

enum LayoutType {
	LINEAR
}

struct Layout {

	LayoutType type;
	this(LayoutType type) {
		this.type = type;
	}

}

struct UIState {

	uint active_item = 0, hot_item = 0;
	int mouse_x, mouse_y;
	uint mouse_buttons;

	//encapsulate this, this is TEMPORARY
	GLuint box_vao;
	GLuint box_vbo;
	Shader box_shader;
	uint box_num_vertices;

	FontAtlas font_atlas;

	void init() {

		//upload the vertex data, transform it when actually drawing
		Vec3f[6] vertices = [

			Vec3f(0.0f, 0.0f, 0.0f), // top left
			Vec3f(1.0f, 0.0f, 0.0f), // top right
			Vec3f(1.0f, 1.0f, 0.0f), // bottom right

			Vec3f(0.0f, 0.0f, 0.0f), // top left
			Vec3f(0.0f, 1.0f, 0.0f), // bottom left
			Vec3f(1.0f, 1.0f, 0.0f) // bottom right

		];

		box_num_vertices = vertices.length;

		glGenVertexArrays(1, &box_vao);
		glBindVertexArray(box_vao);

		glGenBuffers(1, &box_vbo);
		glBindBuffer(GL_ARRAY_BUFFER, box_vbo);
		glBufferData(GL_ARRAY_BUFFER, vertices.length * vertices[0].sizeof, vertices.ptr, GL_STATIC_DRAW);

		glEnableVertexAttribArray(0);
		glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, vertices[0].sizeof, cast(const(void)*)0);

		glBindVertexArray(0); //INDEED

		AttribLocation[1] attrs = [AttribLocation(0, "position")];
		char[16][3] uniforms = ["transform", "perspective", "color"];
		box_shader = Shader("shaders/rectangle", attrs[0..attrs.length], uniforms[0..uniforms.length]);

		int status = glGetError();
		if (status != GL_NO_ERROR) {
			writefln("[GAME] OpenGL ERROR: %d", status);
		}

		font_atlas = FontAtlas("fonts/OpenSans-Bold.ttf", 22);

	}

	~this() {

		glDeleteVertexArrays(1, &box_vao);

	}

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

GLfloat[4] int_to_glcolor(int color, ubyte alpha = 255) {

	GLfloat[4] gl_color = [ //mask out r, g, b components from int
		cast(float)cast(ubyte)(color>>16)/255,
		cast(float)cast(ubyte)(color>>8)/255,
		cast(float)cast(ubyte)(color)/255,
		cast(float)cast(ubyte)(alpha)/255
	];

	return gl_color;

}

//Immediate Mode GUI (IMGUI, see Muratori)
void draw_rectangle(UIState* state, Window* window, float x, float y, float width, float height, int color, ubyte alpha = 255) {

	auto transform = Mat4f.translation(Vec3f(x, y, 0.0f)) * Mat4f.scaling(Vec3f(width, height, 1.0f));
	GLfloat[4] gl_color = int_to_glcolor(color, alpha);

	state.box_shader.bind();
	state.box_shader.update(window.view_projection, transform);
	glUniform4fv(state.box_shader.bound_uniforms[2], 1, gl_color.ptr);

	glBindVertexArray(state.box_vao);
	glDrawArrays(GL_TRIANGLES, 0, state.box_num_vertices);
	glBindVertexArray(0);

	state.box_shader.unbind();

}

void draw_label(UIState* ui, Window* window, in char[] label, int x, int y, int width, int height, int color) {

	int cw = ui.font_atlas.char_width;
	float label_width = (label.length * cw);
	ui.font_atlas.render_text(window, label, (x - label_width/2) - cw*2.05f, y + (cw-cw/5), 1, 1, color);

}

int darken(int color, uint percentage) {

	uint adjustment = 255 / percentage;
	ubyte r = cast(ubyte)(color>>16);
	ubyte g = cast(ubyte)(color>>8);
	ubyte b = cast(ubyte)(color);
	r -= adjustment;
	g -= adjustment;
	b -= adjustment;
	int result = (r << 16) | (g << 8) | b;
	return result;

}

struct TextSpec {
	char[] label;
	int text_color;
}

bool do_button(UIState* ui, uint id, Window* window, int x, int y, int width, int height, int color, ubyte alpha = 255, in char[] label = "", int text_color = 0xFFFFFF) {

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
		
		text_color = darken(text_color, 10);

		if (ui.active_item == 0 && is_btn_down(ui, 1)) {
			ui.active_item = id;
		} else if (ui.active_item == id) {
			m_x += 1;
			m_y += 1;
		}

	}

	//draw both layers of button
	ui.draw_rectangle(window, (x - width/2)+2, (y - height/2)+2, width, height, darken(color, 10), alpha);
	ui.draw_rectangle(window, m_x - width/2, m_y - height/2, width, height, color, alpha);
	if (label != "") ui.draw_label(window, label, m_x, m_y, width, height, text_color);

	return result;

}

bool is_btn_down(UIState* ui, uint button) {

	return (ui.mouse_buttons >> button-1) & 1;

}
