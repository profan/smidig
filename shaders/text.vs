#version 120

attribute vec4 coord;
varying vec2 tex_coord;

uniform mat4 projection;

void main() {
	gl_Position = projection * vec4(coord.xy, 0, 1.0);
	tex_coord = coord.zw;
}
