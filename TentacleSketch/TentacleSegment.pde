
public class TentacleSegment {
  public float length;
  public float angle;
  
  // Position of the end of the tentacle segment relative to the tentacle base.
  public float x;
  public float y;
  
  TentacleSegment(float lengthArg, float angleArg, float xArg, float yArg) {
    length = lengthArg;
    angle = angleArg;
    x = xArg;
    y = yArg;
  }
}
