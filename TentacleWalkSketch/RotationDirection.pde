
public static class RotationDirection {
  public final static int CLOCKWISE = 1;
  public final static int COUNTERCLOCKWISE = -1;

  public static int getRotationSign(PVector sourceVector, PVector targetVector) {
    if (sourceVector.y * targetVector.x > sourceVector.x * targetVector.y) {
      return RotationDirection.COUNTERCLOCKWISE;
    } else {
      return RotationDirection.CLOCKWISE;
    }
  }
}
