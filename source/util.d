module sundownstandoff.util;

bool point_in_rect(int x, int y, int r_x, int r_y, int w, int h) {
	return (x < r_x + w && y < r_y + h && x > r_x && y > r_y);
}
