module blindfire.text;

import std.algorithm : max;
import std.stdio : writefln;

import derelict.freetype.ft;
import derelict.opengl3.gl3;

import blindfire.gl;

struct FontAtlas {

	Texture atlas;

	FT_Library ft;
	FT_GlyphSlot g;

	this(in char[] font_name, uint font_size) {

		if (FT_Init_FreeType(&ft)) { 
			writefln("[GAME] Could not init freetype.");
		}

		FT_Face face;
		if (FT_New_Face(ft, font_name.ptr, 0, &face)) { 
			writefln("[GAME] Could not open font.");
		}

		FT_Set_Pixel_Sizes(face, 0, font_size);

		int w, h;
		for (uint i = 32; i < 128; ++i) {
			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				writefln("Character %c failed to load.", i);
				continue;
			}

			w += g.bitmap.width;
			h = max(h, g.bitmap.rows);

		}

		atlas = Texture(null, w, h, GL_ALPHA, GL_ALPHA);	

	}

	void render_text(char[] text, float x, float y, float sx, float sy) {
		//stuff
	}

	@disable this(this);

	~this() {
		
	}

}
