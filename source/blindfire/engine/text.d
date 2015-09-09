module blindfire.engine.text;

import core.stdc.stdio : printf;

import std.algorithm : max;
import std.stdio : writefln;

import derelict.freetype.ft;
import derelict.opengl3.gl3;

import blindfire.engine.gl;
import blindfire.engine.window : Window;
import blindfire.engine.resource : ResourceManager;

private struct CharacterInfo {

	float advance_x; // advance.x
	float advance_y; // advance.y
 
	float bitmap_width; // bitmap.width;
	float bitmap_height; // bitmap.rows;
 
	float bitmap_left; // bitmap_left;
	float bitmap_top; // bitmap_top;
 
	float tx_offset; // x offset of glyph in texture coordinates
	float tx_offset_y;

}

struct FontAtlas {

	GLuint vao, vbo;
	Shader* shader;
	Texture atlas;
	CharacterInfo[96] characters;

	int atlas_width, atlas_height;
	int char_width, char_height;

	import blindfire.engine.memory;
	StackAllocator stack_allocator;

	this(in char[] font_name, uint font_size, Shader* text_shader) {

		this.stack_allocator = StackAllocator(1024 * 8, "FontAllocator"); //todo nogc this
		this.shader = text_shader;

		glGenVertexArrays(1, &vao);
		glGenBuffers(1, &vbo);

		FT_Library ft;
		FT_Face face;

		if (FT_Init_FreeType(&ft)) { 
			printf("[FontAtlas] Could not init freetype.");
		}

		if (FT_New_Face(ft, font_name.ptr, 0, &face)) { 
			printf("[FontAtlas] Could not open font.");
		}

		scope(exit) {
			FT_Done_Face(face);
			FT_Done_FreeType(ft);
		}

		FT_Set_Pixel_Sizes(face, 0, font_size);	
		FT_GlyphSlot glyph = face.glyph;

		int w = 0, h = 0;
		for (uint i = 32; i < 128; ++i) {

			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				printf("[FontAtlas] Character %c failed to load.", i);
				continue;
			}

			w += glyph.bitmap.width;
			h = max(h, glyph.bitmap.rows);

			this.atlas_width = w;
			this.atlas_height = h;

		}

		this.atlas = Texture(w, h, GL_RED, GL_RED, 1);
		this.atlas.bind(0);

		int x = 0;
		for (uint i = 32; i < 128; ++i) {

			if (FT_Load_Char(face, i, FT_LOAD_RENDER)) {
				continue;
			}

			float top_distance = face.glyph.metrics.horiBearingY; //used to adjust for eventual hang

			glTexSubImage2D(GL_TEXTURE_2D, 0, x, 0, glyph.bitmap.width, glyph.bitmap.rows, GL_RED, GL_UNSIGNED_BYTE, glyph.bitmap.buffer);

			int ci = i - 32;
			this.characters[ci].advance_x = glyph.advance.x >> 6;
			this.characters[ci].advance_y = glyph.advance.y >> 6;

			this.characters[ci].bitmap_width = glyph.bitmap.width;
			this.characters[ci].bitmap_height = glyph.bitmap.rows;

			this.characters[ci].bitmap_left = glyph.bitmap_left;
			this.characters[ci].bitmap_top = glyph.bitmap_top;

			this.characters[ci].tx_offset = cast(float)x / w;
			this.characters[ci].tx_offset_y = (top_distance/64 - (face.glyph.metrics.height>>6));

			x += glyph.bitmap.width;

		}
		
		this.char_width = cast(typeof(char_width))face.glyph.metrics.width >> 6;
		this.char_height = cast(typeof(char_height))face.glyph.metrics.height >> 6;
		this.atlas.unbind();

	}
	
	@disable this(this);

	~this() nothrow @nogc {
		glDeleteBuffers(1, &vbo);
		glDeleteVertexArrays(1, &vao);
	}

	void render_text(Window* window, in char[] text, float x, float y, float sx, float sy, int color) nothrow @nogc {
		
		struct Point {
			GLfloat x;
			GLfloat y;
			GLfloat s;
			GLfloat t;
		}

		Point[] coords = (cast(Point*)stack_allocator.alloc(Point.sizeof * text.length * 6))[0..text.length*6];
		scope(exit) stack_allocator.dealloc(Point.sizeof * text.length * 6); //pop it

		int n = 0; //how many to draw?
		foreach (ch; text) {

			if (ch < 32 || ch > 127) continue;

			int ci = ch - 32; //get char index
			float x2 =  x + characters[ci].bitmap_left * sx;
			float y2 = y + characters[ci].bitmap_top * sy;

			float w = characters[ci].bitmap_width * sx;
			float h = characters[ci].bitmap_height * sy;

			x += characters[ci].advance_x * sx;
			y += characters[ci].advance_y * sy;

			//adjust for hang
			y2 -= (characters[ci].bitmap_top * sy);
			y2 -= (characters[ci].tx_offset_y * sy);

			if (!w || !h) {//continue if no width or height, invisible character
			 	continue;
			}

			coords[n++] = Point(x2, y2, characters[ci].tx_offset, characters[ci].bitmap_height / atlas_height); //top left?
			coords[n++] = Point(x2, y2 - h, characters[ci].tx_offset, 0);

			coords[n++] = Point(x2 + w, y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, characters[ci].bitmap_height / atlas_height);
			coords[n++] = Point(x2 + w, y2, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, characters[ci].bitmap_height / atlas_height);

			coords[n++] = Point(x2, y2 - h, characters[ci].tx_offset, 0);
			coords[n++] = Point(x2 + w, y2 - h, characters[ci].tx_offset + characters[ci].bitmap_width / atlas_width, 0);

		}
	
		import blindfire.engine.gl : int_to_glcolor;
		
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
		shader.update(window.view_projection);

		glBufferData(GL_ARRAY_BUFFER, coords[0].sizeof * coords.length, coords.ptr, GL_DYNAMIC_DRAW);
		glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 0, cast(void*)0);
		glDrawArrays(GL_TRIANGLES, 0, n);

		glBindVertexArray(0);
		shader.unbind();
		atlas.unbind();

	}

	mixin OpenGLError!();

}
