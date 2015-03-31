#version 120

attribute vec4 coord;
varying vec2 tex_coord;

void main() {
	gl_Position = vec4(coord.xy, 0, 1.0);
	tex_coord = coord.zw;
}
