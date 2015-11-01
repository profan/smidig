#version 330 core

uniform mat4 view_projection;

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 tex_coord;
layout (location = 2) in vec2 offset;

out vec2 fs_tex_coord;

void main() {
	gl_Position = view_projection * vec4(position.xy + offset, position.z, 1.0);
	fs_tex_coord = tex_coord;
}
