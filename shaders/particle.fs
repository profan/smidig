#version 330 core

in vec2 fs_tex_coord;

uniform sampler2D diffuse;

void main() {
	gl_FragColor = texture2D(diffuse, fs_tex_coord);
}
