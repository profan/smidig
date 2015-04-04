module blindfire.text;

import std.stdio : writefln;
import derelict.freetype.ft;

import blindfire.gl;

struct FontAtlas {

	Texture atlas;

	FT_Library ft;
	FT_Face face;
	FT_GlyphSlot g;

	this(in char[] font_name, uint font_size) {

		if (FT_Init_FreeType(&ft)) { 
			writefln("[GAME] Could not init freetype.");
		}

		if (FT_New_Face(ft, font_name.ptr, 0, &face)) { 
			writefln("[GAME] Could not open font.");
		}

		FT_Set_Pixel_Sizes(face, 0, font_size);

	}

	void render_text(char[] text, float x, float y, float sx, float sy) {
		//stuff
	}

	@disable this(this);

	~this() {
		
	}

}
