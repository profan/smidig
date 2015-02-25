module sundownstandoff.state;

abstract class GameState {

	void update(double dt);
	void draw();

} //GameState

class MenuState : GameState {

	final override void update(double dt) {
		//do menu stuff
	}

	final override void draw() {

	}

} //MenuState

class MatchState : GameState {

	final override void update(double dt) {

	}

	final override void draw() {

	}

} //MatchState
