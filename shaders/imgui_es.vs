#version 300 es

uniform mat4 ProjMtx;

in highp vec2 Position;
in highp vec2 UV;
in highp vec4 Color;

out highp vec2 Frag_UV;
out highp vec4 Frag_Color;

void main()
{
	Frag_UV = UV;
	Frag_Color = Color;
	gl_Position = ProjMtx * vec4(Position.xy,0,1);
}
