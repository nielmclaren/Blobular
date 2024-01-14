
public class TentacleSegment {
  public float length;
  public float angle;
  
  // Constrain angle relative to previous segment angle.
  public float maxAngleDelta;
  
  // Position of the end of the tentacle segment relative to the tentacle base.
  public float x;
  public float y;
  
  TentacleSegment(float lengthArg, float angleArg, float xArg, float yArg, float maxAngleDeltaArg) {
    length = lengthArg;
    angle = angleArg;
    x = xArg;
    y = yArg;
    maxAngleDelta = maxAngleDeltaArg;
  }
  
  // Get a vector representing this segment's length and angle.
  public PVector getVector() {
    return new PVector(length * cos(angle), length * sin(angle));
  }
}
