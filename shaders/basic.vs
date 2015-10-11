#version 330

in vec3 position;
in vec2 tex_coord;

out vec2 tex_coord0;

uniform mat4 transform;
uniform mat4 perspective;

void main() {
	gl_Position = perspective * transform * vec4(position, 1.0);
	tex_coord0 = tex_coord;
}
