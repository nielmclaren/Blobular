
public class TentacleSegment {
  protected TentacleSegment parent;

  // Position of the end of the tentacle segment relative to the tentacle base.
  protected PVector endpoint;

  protected float length;
  protected float angle;
  
  // Constrain how quickly the angle can change.
  public float maxAngleDelta;
  
  public boolean isFixed;
  
  TentacleSegment(TentacleSegment parentArg, float lengthArg, float angleArg, float maxAngleDeltaArg) {
    parent = parentArg;

    length = lengthArg;
    angle = angleArg;
    endpoint = new PVector();
    updateEndpoint();

    maxAngleDelta = maxAngleDeltaArg;
    isFixed = false;
  }

  public float length() {
    return length;
  }

  public float angle() {
    return angle;
  }

  public void angle(float v) {
    angle = v;
    updateEndpoint();
  }

  public float pivotX() {
    return parent == null ? 0 : parent.endpointX();
  }

  public float pivotY() {
    return parent == null ? 0 : parent.endpointY();
  }
  
  public float endpointX() {
    return endpoint.x;
  }

  public float endpointY() {
    return endpoint.y;
  }
  
  // Get a vector representing this segment's length and angle.
  public PVector getVector() {
    return new PVector(length * cos(angle), length * sin(angle));
  }

  private void updateEndpoint() {
    endpoint.x = (parent == null ? 0 : parent.endpointX()) + length * cos(angle);
    endpoint.y = (parent == null ? 0 : parent.endpointY()) + length * sin(angle);
  }
}
