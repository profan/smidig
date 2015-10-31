#version 330 core

in vec2 fs_tex_coord;
in vec3 fs_color;

out vec4 out_color;

void main() {
	out_color = fs_color;
}
