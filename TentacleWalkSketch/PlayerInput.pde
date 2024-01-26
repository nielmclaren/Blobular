import java.util.Map;

class PlayerInput {
  private TentacleWalkSketch sketch;
  Map<String, Boolean> isKeyDownMap;

  PlayerInput(TentacleWalkSketch sketchArg) {
    sketch = sketchArg;

    isKeyDownMap = new HashMap<String, Boolean>();
  }

  public void keyPressed(char key) {
    isKeyDownMap.put(String.valueOf(key), true);
  }

  public void keyReleased(char key) {
    isKeyDownMap.put(String.valueOf(key), false);
  }

  public boolean isKeyDown(char key) {
    String keyString = String.valueOf(key);
    return isKeyDownMap.containsKey(keyString) && isKeyDownMap.get(keyString);
  }
}