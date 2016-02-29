module smidig.render;

import derelict.opengl3.gl3;

struct DrawParams {

	GLenum blend_test;

	/**
	 * Enables the given parameters, and returns a
	 * structure representing the last state.
	*/
	DrawParams set(ref Renderer r) {

		DrawParams last = { r.blend_test; };

		r.blend_test = blend_test;
		glEnable(blend_test);

		return last;

	} //set

} //DrawParams

enum BlendMode {

	Disabled,
	Enabled

} //BlendMode

/**
 * Struct which still store all OpenGL state internally, minimizing the total number of state changes to the
 * greatest extent possible, also making it possible to track certain statistics of graphics API usage
 * like drawcalls and such.
*/
struct Renderer {
static:

	/**
	 * Current Values and Associated Data
	*/

	//GL_CURRENT_COLOR

	/**
	 * Vertex Array
	*/

	//GL_ARRAY_BUFFER_BINDING
	GLuint array_buffer_binding;

	//GL_ELEMENT_ARRAY_BUFFER_BINDING
	GLuint element_array_buffer_binding;

	//GL_VERTEX_ARRAY_BUFFER_BINDING
	GLuint vertex_array_buffer_binding;

	/**
	 * Transformation
	*/

	//GL_VIEWPORT

	/**
	 * Coloring
	*/

	/**
	 * Rasterization
	*/

	//GL_POINT_SIZE

	//GL_POINT_SMOOTH

	//GL_LINE_WIDTH

	//GL_LINE_SMOOTH

	//GL_CULL_FACE

	//GL_CULL_FACE_MODE

	//GL_FRONT_FACE

	//GL_POLYGON_MODE

	/**
	 * Texturing
	*/

	//GL_TEXTURE_2D
	bool texture_2d;

	//GL_TEXTURE_BINDING_2D
	GLuint texture_binding_2d;

	/**
	 * Pixel Operations
	*/

	//GL_SCISSOR_TEST
	bool scissor_test;

	//GL_SCISSOR_BOX
	GLint[4] scissor_box;

	//GL_ALPHA_TEST
	bool alpha_test;

	//GL_ALPHA_TEST_FUNC
	GLenum alpha_test_func;

	//GL_STENCIL_TEST
	bool stencil_test;

	//GL_STENCIL_FUNC
	GLenum stencil_test_func;

	//GL_DEPTH_TEST
	bool depth_test;

	//GL_DEPTH_FUNC
	GLenum depth_test_func;

	//GL_BLEND
	bool blend_test;

	//GL_BLEND_SRC
	GLenum blend_src;

	//GL_BLEND_DST
	GLenum blend_dst;

	/**
	 * Framebuffer Control
	*/

	//GL_DRAW_BUFFER

	/**
	 * Implementation-Dependant Values
	*/

	//GL_MAX_TEXTURE_SIZE

	//GL_MAX_VIEWPORT_DIMS

	//GL_RGBA_MODE

	//GL_INDEX_MODE

	//GL_DOUBLEBUFFER

	//GL_STEREO

	/**
	 * Functions
	*/

	void initialize() {

	} //initialize

	void bindVertexArray(GLuint id) {

		GLuint last_id = vertex_array_buffer_binding;

		if (last_id == id) { return; }

		glBindVertexArray(id);

	} //bindVertexArray

	void bindBuffer(GLenum type, GLuint id) {

		GLuint last_id;

		if (type == GL_ARRAY_BUFFER) {

			if (array_buffer_binding == id) { return; }
			array_buffer_binding = id;

		} else if (type == GL_ELEMENT_ARRAY_BUFFER) {

			if (element_array_buffer_binding = id) { return; }
			element_array_buffer_binding = id;

		}

		//if we get here, actually do bind
		glBindBuffer(type, id);

	} //bindBuffer

	void bufferData(GLenum type, size_t size, void* data, GLenum draw_hint) {

		glBufferData(type, size, data, draw_hint);

	} //bufferData

	void drawArrays(GLenum primitives, int first, size_t count, DrawParams params) {

		auto last_state = params.set();

		glDrawArrays(primitives, first, count);

		last_state.set();

	} //drawArrays

	void drawElements(GLenum primitives, size_t count, GLenum prim_type, size_t offset) {

		auto last_state = params.set();

		glDrawElements(primitives, count, prim_type, offset);

		last_state.set();

	} //drawElements

} //Renderer
