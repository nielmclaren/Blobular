
public class TentacleSegment {
  // Position of the start of the tentacle segment relative to the tentacle base. The segment rotates around this point.
  protected PVector pivot;

  // Position of the end of the tentacle segment relative to the tentacle base. This point depends on pivot, length, and angle.
  protected PVector endpoint;

  protected float length;
  protected float angle;
  
  // Constrain how quickly the angle can change.
  public float maxAngleDelta;
  
  // Indicate whether this segment's endpoint is fixed.
  public boolean isFixed;

  // The side of the tentacle that is fixed to a surface. Indicated by the direction to rotate towards the surface.
  public int fixedRotationDirection;
  
  TentacleSegment(float lengthArg, float angleArg, float maxAngleDeltaArg) {
    length = lengthArg;
    angle = angleArg;
    pivot = new PVector();
    endpoint = new PVector();

    maxAngleDelta = maxAngleDeltaArg;
    isFixed = false;
    fixedRotationDirection = 0;
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

  public PVector pivot() {
    return pivot.copy();
  }

  public void pivot(PVector v) {
    pivot.set(v);
  }

  public void pivot(float x, float y) {
    pivot.set(x, y);
  }

  public float pivotX() {
    return pivot.x;
  }

  public void pivotX(float v) {
    pivot.x = v;
  }

  public float pivotY() {
    return pivot.y;
  }
  
  public void pivotY(float v) {
    pivot.y = v;
  }

  public PVector endpoint() {
    return endpoint.copy();
  }

  public void endpoint(PVector v) {
    endpoint.set(v);
  }

  public void endpoint(float x, float y) {
    endpoint.set(x, y);
  }

  public float endpointX() {
    return endpoint.x;
  }

  public void endpointX(float v) {
    endpoint.x = v;
  }

  public float endpointY() {
    return endpoint.y;
  }

  public void endpointY(float v) {
    endpoint.y = v;
  }

  // Move the pivot and the endpoint by the specified amount.
  public void shift(float x, float y) {
    pivot.x += x;
    pivot.y += y;
    endpoint.x += x;
    endpoint.y += y;
  }
  
  // Get a vector representing this segment's length and angle.
  public PVector getVector() {
    return new PVector(length * cos(angle), length * sin(angle));
  }

  // Update pivot based on the endpoint, angle, and length.
  public void updatePivot() {
    pivot.x = endpoint.x - length * cos(angle);
    pivot.y = endpoint.y - length * sin(angle);
  }

  // Update endpoint based on the pivot, angle, and length.
  public void updateEndpoint() {
    endpoint.x = pivot.x + length * cos(angle);
    endpoint.y = pivot.y + length * sin(angle);
  }
}
