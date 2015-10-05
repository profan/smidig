module blindfire.engine.render;

import std.stdio : writefln;

import blindfire.engine.defs : RenderSpriteEvent;

interface Renderer {

	void on_render_sprite_event(RenderSpriteEvent* event);

} //Renderer

class OpenGLRenderer : Renderer {

	void on_render_sprite_event(RenderSpriteEvent* event) {

		writefln("rendered sprite: %s", event.payload);

	} //on_render_sprite_event

} //OpenGLRenderer