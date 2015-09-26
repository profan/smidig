module blindfire.engine.render;

import blindfire.engine.defs : RenderSpriteEvent;

struct Renderer {

	//disallow copying and default construction
	@disable this();
	@disable this(this);

	void onRenderSprite(RenderSpriteEvent* ev) {

	} //onRenderSprite

} //Renderer