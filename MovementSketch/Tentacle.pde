import java.util.List;

public class Tentacle {
  // TODO: Protect this member.
  public PVector position;
  
  // TODO: Protect this member.
  public float baseAngle;
  
  // TODO: Protect this member.
  public List<TentacleSegment> segments;
  
  Tentacle(float x, float y, float baseAngleArg) {
    position = new PVector(x, y);
    baseAngle = baseAngleArg;
    segments = new ArrayList<TentacleSegment>();
    initSegments();
  }
  
  Tentacle(PVector v, float baseAngleArg) {
    position = v.copy();
    baseAngle = baseAngleArg;
    segments = new ArrayList<TentacleSegment>();
    initSegments();
  }
  
  void initSegments() {
    float segmentLength = 10;
    
    for (int i = 0;  i < 8; i++) {
      segments.add(new TentacleSegment(segmentLength, baseAngle));
    }
  }
}
