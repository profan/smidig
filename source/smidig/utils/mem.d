module smidig.utils.mem;

import derelict.imgui.imgui;

struct MemoryEditor {

	bool open_ = true;
	bool allow_edits_ = true;
	int rows_ = 16;

	int data_editing_addr_ = -1;
	bool data_editing_take_focus_ = false;

	char[32] data_input_;
	char[32] addr_input_;

	void draw(in char[] title, ubyte[] mem, size_t base_display_addr = 0) {

		if (igBegin(title.ptr, &open_)) {

			igBeginChild("##scrolling", ImVec2(0, -igGetItemsLineHeightWithSpacing()));

			igPushStyleVarVec(ImGuiStyleVar_FramePadding, ImVec2(0, 0));
			igPushStyleVarVec(ImGuiStyleVar_ItemSpacing, ImVec2(0, 0));

			int addr_digits_count = 0;
			for (int n = cast(int)(base_display_addr + mem.length - 1); n > 0; n >>= 4) {
				addr_digits_count++;
			}

			ImVec2 t_size;
			igCalcTextSize(&t_size, "F");
			float glyph_width = t_size.x;
			float cell_width = glyph_width * 3;

			float line_height = igGetTextLineHeight();
			int line_total_count = cast(int)((mem.length + rows_ - 1) / rows_);

			int display_start, display_end;
			igCalcListClipping(line_total_count, line_height, &display_start, &display_end);
			igSetCursorPosY(igGetCursorPosY() + (display_start * line_height));
			int visible_start_addr = display_start * rows_;
			int visible_end_addr = display_end * rows_;

			bool data_next = false;

			if (!allow_edits_ || data_editing_addr_ >= mem.length) {
				data_editing_addr_ = -1;
			}

			int data_editing_addr_backup = data_editing_addr_;
			if (data_editing_addr_ != -1) {
				import derelict.sdl2.sdl;
				if (igIsKeyPressed(SDL_SCANCODE_UP) && data_editing_addr_ >= rows_) {
					data_editing_addr_ -= rows_;
					data_editing_take_focus_ = true;
				} else if (igIsKeyPressed(SDL_SCANCODE_DOWN) && data_editing_addr_ < mem.length - rows_) {
					data_editing_addr_ += rows_;
					data_editing_take_focus_ = true;
				} else if (igIsKeyPressed(SDL_SCANCODE_LEFT) && data_editing_addr_ > 0) {
					data_editing_addr_ -= 1;
					data_editing_take_focus_ = true;	
				} else if (igIsKeyPressed(SDL_SCANCODE_RIGHT) && data_editing_addr_ < mem.length - 1) {
					data_editing_addr_ += 1;
					data_editing_take_focus_ = true;
				}
			}

			if ((data_editing_addr_ / rows_) != (data_editing_addr_backup / rows_)) {

				float scroll_offset = ((data_editing_addr_ / rows_) - (data_editing_addr_backup / rows_) * line_height);
				bool scroll_desired = (scroll_offset < 0.0f && data_editing_addr_ < visible_start_addr + rows_*2) ||
					(scroll_offset > 0.0f && data_editing_addr_ > visible_end_addr - rows_*2);

				if (scroll_desired) {
					igSetScrollY(cast(int)(igGetScrollY() + scroll_offset));
				}

			}

			bool draw_separator = true;
			foreach (line_i; display_start .. display_end) {

				int addr = line_i * rows_;
				igText("%0*X: ", addr_digits_count, base_display_addr + addr);
				igSameLine();

				// draw hexadecimal
				float line_start_x = igGetCursorPosX();
				for (int n = 0; n < rows_ && addr < mem.length; n++, addr++) {

					igSameLine();

					if (data_editing_addr_ == addr) {

						igPushIdInt(addr);
						struct FuncHolder {
							static int callback(ImGuiTextEditCallbackData* data) {
								int* p_cursor_pos = cast(int*)data.UserData;
								if (!(data.SelectionStart != data.SelectionEnd)) {
									*p_cursor_pos = data.CursorPos;
								}
								return 0;
							} //callback
						} //FuncHolder

						int cursor_pos = -1;
						bool data_write = false;

						if (data_editing_take_focus_) {

							import smidig.util : cformat;

							igSetKeyboardFocusHere();
							cformat(addr_input_, "%0*X", addr_digits_count, base_display_addr+addr);
							cformat(data_input_, "%02X", mem[addr]);

						}

						ImVec2 tsz;
						igCalcTextSize(&tsz, "FF");
						igPushItemWidth(tsz.x);
						ImGuiInputTextFlags flags = ImGuiInputTextFlags_CharsHexadecimal 
							| ImGuiInputTextFlags_EnterReturnsTrue
							| ImGuiInputTextFlags_AutoSelectAll
							| ImGuiInputTextFlags_NoHorizontalScroll
							| ImGuiInputTextFlags_AlwaysInsertMode
							| ImGuiInputTextFlags_CallbackAlways;

						if (igInputText("##data", data_input_.ptr, data_input_.length, flags, &FuncHolder.callback, cast(void*)&cursor_pos)) {
							data_write = data_next = true;
						} else if (data_editing_take_focus_ && !igIsItemActive()) {
							data_editing_addr_ = -1;
						}

						data_editing_take_focus_ = false;
						igPopItemWidth();

						if (cursor_pos >= 2) {
							data_write = data_next = true;
						}

						if (data_write) {

							import core.stdc.stdio : sscanf;

							int data;
							if (sscanf(data_input_.ptr, "%X", &data) == 1) {
								mem[addr] = cast(ubyte)data;
							}

						}

						igPopId();

					} else {

						igText("%02X ", mem[addr]);
						if (allow_edits_ && igIsItemHovered() && igIsMouseClicked(0)) {
							data_editing_take_focus_ = true;
							data_editing_addr_ = addr;
						}

					}

				}

				igSameLine(line_start_x + cell_width * rows_ + glyph_width * 2);

				if (draw_separator) {

					ImVec2 screen_pos;
					igGetCursorScreenPos(&screen_pos);
					//FIXME add the missing parts to the API!
					/* igGetWindowDrawList().AddLine(ImVec2(screen_pos.x - glyph_width, screen_pos.y - 9999), 
							ImVec2(screen_pos.x - glyph_width, screen_pos.y + 9999), 
							ImColor(igGetStyle().Colors[ImGuiCol_Border])); */
					draw_separator = false;

				}

				addr = line_i * rows_;
				for (int n = 0; n < rows_ && addr < mem.length; n++, addr++) {

					if (n > 0) igSameLine();

					int c = mem[addr];
					igText("%c", (c >= 32 && c < 128) ? c : '.');

				}

			}

			// ... end clip
			igSetCursorPosY(igGetCursorPosY() + ((line_total_count - display_end) * line_height));
			igPopStyleVar(2);

			igEndChild();

			if (data_next && data_editing_addr_ < mem.length) {

				data_editing_addr_ += 1;
				data_editing_take_focus_ = true;

			}

			igSeparator();

			igAlignFirstTextHeightToWidgets();
			igPushItemWidth(50);
			igPushAllowKeyboardFocus(false);

			int rows_backup = rows_;

			if (igDragInt("##rows", &rows_, 0.2f, 4, 32, "%.0f rows")) {

				ImVec2 new_window_size;
				igGetWindowSize(&new_window_size);
				new_window_size.x += ((rows_ - rows_backup) * cell_width + glyph_width);
				igSetWindowSize(new_window_size);

			}

			igPopAllowKeyboardFocus();
			igPopItemWidth();
			igSameLine();

			igText("Range %0*X..%0*X", addr_digits_count, cast(int)base_display_addr, addr_digits_count, 
					cast(int)base_display_addr + mem.length - 1);
			igSameLine();

			igPushItemWidth(70);
			if (igInputText("##addr", addr_input_.ptr, 32, ImGuiInputTextFlags_CharsHexadecimal | ImGuiInputTextFlags_EnterReturnsTrue)) {

				import core.stdc.stdio : sscanf;

				int goto_addr;
				if (sscanf(addr_input_.ptr, "%X", &goto_addr) == 1) {

					goto_addr -= base_display_addr;
					if (goto_addr >= 0 && goto_addr < mem.length) {
						igBeginChild("##scrolling");
						ImVec2 cursor_start_pos;
						igGetCursorStartPos(&cursor_start_pos);
						igSetScrollFromPosY(cursor_start_pos.y + (goto_addr / rows_) * igGetTextLineHeight());
						igEndChild();
						data_editing_addr_ = goto_addr;
						data_editing_take_focus_ = true;
					}

				}

			}

			igPopItemWidth();

		}

		igEnd();

	} //draw

}
