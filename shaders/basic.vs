#version 330

attribute vec3 position;
attribute vec2 tex_coord;

varying vec2 tex_coord0;

uniform mat4 transform;
uniform mat4 perspective;

void main() {
	gl_Position = perspective * transform * vec4(position, 1.0);
	tex_coord0 = tex_coord;
}
