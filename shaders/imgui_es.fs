#version 300 es

uniform sampler2D Texture;

in highp vec2 Frag_UV;
in highp vec4 Frag_Color;

out highp vec4 Out_Color;

void main()
{
	Out_Color = Frag_Color * texture( Texture, Frag_UV.st);
}
