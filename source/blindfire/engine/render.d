module blindfire.engine.render;

import std.stdio : writefln;

import blindfire.engine.defs : RenderSpriteEvent;

interface IRenderer {

	void onRenderSpriteEvent(RenderSpriteEvent* event);

} //Renderer

class OpenGLRenderer : IRenderer {

	void onRenderSpriteEvent(RenderSpriteEvent* event) {

		writefln("rendered sprite: %s", event.payload);

	} //onRenderSpriteEvent

} //OpenGLRenderer