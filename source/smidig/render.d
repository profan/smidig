module smidig.render;

import std.stdio : writefln;

import smidig.defs : RenderSpriteEvent;

interface IRenderer {

	void onRenderSpriteEvent(RenderSpriteEvent* event);

} //Renderer

class OpenGLRenderer : IRenderer {

	void onRenderSpriteEvent(RenderSpriteEvent* event) {

		writefln("rendered sprite: %s", event.payload);

	} //onRenderSpriteEvent

} //OpenGLRenderer