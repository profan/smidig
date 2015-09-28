module blindfire.engine.render;

import blindfire.engine.defs : RenderSpriteEvent;

struct Renderer {

	@disable this();
	@disable this(this); //disallow copying and default construction

	void onRenderSprite(RenderSpriteEvent* ev) {

	} //onRenderSprite

} //Renderer