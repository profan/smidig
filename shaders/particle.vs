#version 330 core

uniform mat4 view_projection;

layout (location = 0) in vec2 position;
layout (location = 1) in vec3 color;
layout (location = 2) in vec2 tex_coord;

out vec2 fs_tex_coord;
out vec3 fs_color;

void main() {
	gl_Position = world_projection * vec4(position, 1.0, 1.0);
	out_tex_coord = tex_coord;
	out_color = color;
}
