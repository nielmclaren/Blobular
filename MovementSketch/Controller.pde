
public class Controller {
  private Player player;
  private PVector inputDirection;
  
  private boolean isUpPressed;
  private boolean isLeftPressed;
  private boolean isDownPressed;
  private boolean isRightPressed;
  
  Controller(Player p) {
    player = p;
    inputDirection = new PVector();
    
    isUpPressed = false;
    isLeftPressed = false;
    isDownPressed = false;
    isRightPressed = false;
  }
  
  public void up(boolean v) {
    isUpPressed = v;
  }
  
  public void left(boolean v) {
    isLeftPressed = v;
  }
  
  public void down(boolean v) {
    isDownPressed = v;
  }
  
  public void right(boolean v) {
    isRightPressed = v;
  }
  
  public void step() {
    int x = 0;
    int y = 0;
    
    if (isUpPressed) {
      y -= 1;
    }
    if (isLeftPressed) {
      x -= 1;
    }
    if (isDownPressed) {
      y += 1;
    }
    if (isRightPressed) {
      x += 1;
    }
    
    inputDirection.set(x, y);
    
    player.steerToward(inputDirection);
  }
  
  public void isRunning(boolean v) {
    player.isRunning(v);
  }
}
