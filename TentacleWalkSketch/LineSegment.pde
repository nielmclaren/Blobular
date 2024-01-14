
public class LineSegment {
  public float x0;
  public float y0;
  public float x1;
  public float y1;
  
  LineSegment(PVector p0, PVector p1) {
    x0 = p0.x;
    y0 = p0.y;
    x1 = p1.x;
    y1 = p1.y;
  }
}
