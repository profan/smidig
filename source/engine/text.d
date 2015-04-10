module blindfire.text;

import std.algorithm : max;
import std.stdio : writefln;

import derelict.freetype.ft;
import derelict.opengl3.gl3;

import blindfire.gl;

struct CharacterInfo {

	float advance_x; // advance.x
	float advance_y; // advance.y
 
	float bitmap_width; // bitmap.width;
	float bitmap_height; // bitmap.rows;
 
	float bitmap_left; // bitmap_left;
	float bitmap_top; // bitmap_top;
 
	float tx_offset; // x offset of glyph in texture coordinates

}

struct FontAtlas {

	Shader* shader;
	Texture atlas;
	CharacterInfo[96] characters;

	GLuint vao, vbo;

	FT_Library ft;

	int atlas_width, atlas_height;

	this(in char[] font_name, uint font_size) {

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);

		if (FT_Init_FreeType(&ft)) { 
			writefln("[GAME] Could not init freetype.");
		}

		FT_Face face;
		if (FT_New_Face(ft, font_name.ptr, 0, &face)) { 
			writefln("[GAME] Could not open font.");
		}

		FT_Set_Pixel_Sizes(face, 0, font_size);
		
		FT_GlyphSlot glyph = face.glyph;

		int w = 0, h = 0;
		for (uint i = 32; i < 128; ++i) {
			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				writefln("Character %c failed to load.", i);
				continue;
			}

			w += glyph.bitmap.width;
			h = max(h, glyph.bitmap.rows);

			atlas_width = w;
			atlas_height = h;

		}

		import blindfire.game : Resource;
		import blindfire.resource : ResourceManager;

		auto rm = ResourceManager.get();
		shader = rm.get_resource!(Shader)(Resource.TEXT_SHADER);
		atlas = Texture(w, h, GL_RED, GL_RED, 1);
		glBindTexture(GL_TEXTURE_2D, atlas.texture);

		int x = 0;
		for (uint i = 32; i < 128; ++i) {
			if (FT_Load_Char(face, i, FT_LOAD_RENDER))
				continue;

			glTexSubImage2D(GL_TEXTURE_2D, 0, x, 0, glyph.bitmap.width, glyph.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, glyph.bitmap.buffer);

			int ci = i - 32;
			characters[ci].advance_x = glyph.advance.x >> 6;
			characters[ci].advance_y = glyph.advance.y >> 6;

			characters[ci].bitmap_width = glyph.bitmap.width;
			characters[ci].bitmap_height = glyph.bitmap.rows;

			characters[ci].bitmap_left = glyph.bitmap_left;
			characters[ci].bitmap_top = glyph.bitmap_top;

			characters[ci].tx_offset = cast(float)x / w;

			x += glyph.bitmap.width;

		}
		
		
		glBindTexture(GL_TEXTURE_2D, 0);
		

	}
	
	@disable this(this);

	~this() {
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
	}

	void render_text(in char[] text, float x, float y, float sx, float sy, int color) {
		//stuff
		
		struct Point {
			GLfloat x;
			GLfloat y;
			GLfloat s;
			GLfloat t;
		}

		import core.stdc.stdlib : free, malloc;
		Point* coords_alloc = cast(Point*)malloc((Point.sizeof * text.length)*6);
		Point[] coords = coords_alloc[0..text.length*6];

		int n = 0; //how many to draw?
		foreach (ch; text) {

			int ci = ch - 32; //get char index
			float x2 =  x + characters[ci].bitmap_left * sx;
			float y2 = -y - characters[ci].bitmap_top * sy;

			float w = characters[ci].bitmap_width * sx;
			float h = characters[ci].bitmap_height * sy;

			x += characters[ci].advance_x * sx;
			y += characters[ci].advance_y * sy;

			//if (!w || !h)
			//	continue;

			coords[n++] = Point(x2, -y2, characters[ci].tx_offset, 0); //top left?
			coords[n++] = Point(x2 + w, -y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, 0);

			coords[n++] = Point(x2, -y2 - h, characters[ci].tx_offset, characters[ci].bitmap_height / atlas_height);
			coords[n++] = Point(x2 + w, -y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, 0);

			coords[n++] = Point(x2, -y2 - h, characters[ci].tx_offset, characters[ci].bitmap_height / atlas_height);
			coords[n++] = Point(x2 + w, -y2 - h, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, characters[ci].bitmap_height / atlas_height);

		}
	
		import blindfire.ui : int_to_glcolor;
		
		glEnable(GL_BLEND);
		glDisable(GL_CULL_FACE);
		glDisable(GL_DEPTH_TEST);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

		atlas.bind(0);
		shader.bind();
		glBindVertexArray(vao);
		glEnableVertexAttribArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, vbo);

		GLfloat[4] col = int_to_glcolor(color);
		glUniform4fv(shader.bound_uniforms[0], 1, col.ptr);

		glBufferData(GL_ARRAY_BUFFER, coords[0].sizeof * coords.length, coords.ptr, GL_DYNAMIC_DRAW);
		glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		glDrawArrays(GL_TRIANGLES, 0, n);

		free(coords_alloc);
		glBindVertexArray(0);
		shader.unbind();
		atlas.unbind();

	}

}
