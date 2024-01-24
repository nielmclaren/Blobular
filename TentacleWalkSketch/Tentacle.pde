
public class Tentacle {
  protected List<TentacleSegment> segments;
  protected List<TentacleInstruction> instructions;

  public Tentacle() {
    segments = new ArrayList<TentacleSegment>();
    instructions = new ArrayList<TentacleInstruction>();

    initSegments();
  }

  private void initSegments() {
    float baseSegmentLength = 60;
    float tipSegmentLength = 10;
    float baseAngle = radians(90);
    int numSegments = 8;

    PVector currPos = new PVector();
    
    for (int i = 0;  i < numSegments; i++) {
      float segmentLength = map(i, 0, numSegments, baseSegmentLength, tipSegmentLength);
      TentacleSegment segment = new TentacleSegment(
        segmentLength,
        baseAngle + radians(30) * i,
        radians(20));

      segment.pivot(currPos);
      currPos.add(segment.getVector());
      segment.endpoint(currPos);

      segments.add(segment);
    }
  }

  public List<TentacleSegment> segments() {
    // TODO: Protect this accessor?
    return segments;
  }

  public void pointTo(PVector direction) {
    instructions.clear();

    TentacleInstruction instruction = new TentacleInstruction();
    instruction.targetDirection = direction;
    instructions.add(instruction);
  }

  public void shiftBase(float x, float y) {
    // Shift all segments in the opposite direction.
    for (TentacleSegment segment : segments) {
      segment.shift(-x, -y);
    }

    ikToShiftedBase();
  }

  private void ikToShiftedBase() {
    // The segments from the base up to but not including the first fixed segment
    // will be able to move toward the new base via ik.
    int fixedSegmentIndex = getFirstFixedSegmentIndex();
    int unfixedSegmentIndex;
    if (fixedSegmentIndex < 0) {
      // No segments are fixed so they can all move toward the new base.
      unfixedSegmentIndex = segments.size() - 1;
    } else if (fixedSegmentIndex == 0) {
      // First segment is fixed so unfix it.
      unfixedSegmentIndex = 0;
      TentacleSegment firstSegment = segments.get(0);
      firstSegment.isFixed = false;
    } else {
      // The last unfixed segment before the first fixed segment.
      unfixedSegmentIndex = fixedSegmentIndex - 1;
    }

    // Change segments to unfixed until there is enough tentacle length to
    // cover the distance to the tentacle base.
    int ikStartIndex;
    for (ikStartIndex = unfixedSegmentIndex; ikStartIndex < segments.size() - 1; ikStartIndex++) {
      TentacleSegment segment = segments.get(ikStartIndex);
      float distToTarget = segment.endpoint().mag();
      float availableLength = getLengthBetweenIncl(0, ikStartIndex);

      segment.isFixed = false;

      if (availableLength >= distToTarget) {
        break;
      }
    }

    // IK
    // TODO: Improve iteration. I.e., check error value and break early.
    for (int iteration = 0; iteration < 20; iteration++) {
      PVector base = new PVector();
      for (int i = 0; i <= ikStartIndex; i++) {
        PVector target;
        if (i > 0) {
          TentacleSegment prevSegment = segments.get(i - 1);
          target = prevSegment.endpoint();
        } else {
          target = new PVector();
        }

        TentacleSegment segment = segments.get(i);
        PVector targetToEndpoint = PVector.sub(segment.endpoint(), target);
        segment.angle(targetToEndpoint.heading());
        segment.pivot(target);
        segment.updateEndpoint();
      }
    }

    updateSegmentPivotsAndEndpoints(0);
  }

  private int getFirstFixedSegmentIndex() {
    for (int i = 0; i < segments.size(); i++) {
      TentacleSegment segment = segments.get(i);
      if (segment.isFixed) {
        return i;
      }
    }
    return -1;
  }

  // Includes the length of both the specified segments.
  private float getLengthBetweenIncl(int startSegmentIndex, int endSegmentIndex) {
    float total = 0;
    for (int i = startSegmentIndex; i <= endSegmentIndex; i++) {
      TentacleSegment segment = segments.get(i);
      total += segment.length();
    }
    return total;
  }

  public void step(int count) {
    for (int i = 0; i < count; i++) {
      step();
    }
  }

  public void step() {
    for (TentacleInstruction instruction : instructions) {
      TentacleSegment segment = segments.get(instruction.segmentIndex);
      PVector pivot = segment.pivot();
      PVector segmentVector = segment.getVector();
      
      float prevRotation = segment.angle();
      float angleError = radians(0.5);
      float angleDelta = min(PVector.angleBetween(segmentVector, instruction.targetDirection), segment.maxAngleDelta);
      
      int angleSign;
      if (instruction.rotationDirection == 0) {
        angleSign = getRotationSign(segmentVector, instruction.targetDirection);
      } else {
        angleSign = instruction.rotationDirection;
      }
      
      segment.angle(segment.angle() + angleSign * angleDelta);
      segment.updateEndpoint();
      
      boolean collided = handleCollisions(segment, prevRotation, angleSign, angleDelta);
      if (collided) {
        instruction.rotationDirection = angleSign;
        segment.isFixed = true;
      }
      
      dragRemainingSegments(instruction.segmentIndex + 1);
      
      // If this segment is in position then move onto next segment for the next iteration.
      angleDelta = min(PVector.angleBetween(segment.getVector(), instruction.targetDirection), segment.maxAngleDelta);
      if (collided || angleDelta <= angleError) {
        instruction.segmentIndex++;
        if (instruction.segmentIndex >= segments.size()) {
          instruction.isComplete = true;
        }
      }
    } 

    instructions.removeIf(instruction -> instruction.isComplete);
  }

  public float length() {
    float total = 0;
    for (TentacleSegment segment : segments) {
      total += segment.length();
    }
    return total;
  }

  private boolean handleCollisions(TentacleSegment segment, float prevRotation, int angleSign, float angleDelta) {
    // FIXME: Assumes segment was not originally in a collided state.
    if (detectCollision(segment)) {
      println("handling collision");
      segment.isFixed = true;

      // Rotate 1° at a time until collision detected.
      float prevAngle = 0;
      for (float a = 0; a < angleDelta; a += radians(1)) {
        segment.angle(prevRotation + angleSign * a);
        segment.updateEndpoint();
        
        if (detectCollision(segment)) {
          break;
        }
        
        prevAngle = segment.angle();
      }
      
      segment.angle(prevAngle);
      segment.updateEndpoint();
      
      return true;
    }
    return false;
  }

  private boolean detectCollision() {
    for (TentacleSegment segment : segments) {
      if (detectCollision(segment)) {
        return true;
      }
    }
    return false;
  }

  private boolean detectCollision(TentacleSegment segment) {
    return tentacleY + segment.endpointY() > surfaceY;
  }

  private void updateSegmentPivotsAndEndpoints(int startSegmentIndex) {
    for (int i = startSegmentIndex; i < segments.size(); i++) {
      TentacleSegment segment = segments.get(i);
      if (i > 0) {
        TentacleSegment prevSegment = segments.get(i - 1);
        segment.pivot(prevSegment.endpoint());
      } else {
        segment.pivot(new PVector());
      }
      segment.updateEndpoint();
    }
  }

  // Rotate the each segment around its endpoint so it
  // points at the previous segment's endpoint. Then move
  // the segment's pivot to the previous segment's endpoint.
  private void dragRemainingSegments(int startSegmentIndex) {
    for (int i = startSegmentIndex; i < segments.size(); i++) {
      PVector target;
      if (i > 0) {
        TentacleSegment prevSegment = segments.get(i - 1);
        target = prevSegment.endpoint();
      } else {
        target = new PVector(0, 0);
      }
    
      TentacleSegment segment = segments.get(i);
      PVector endpoint = segment.endpoint();
      PVector targetToEndpoint = PVector.sub(endpoint, target);
      
      segment.pivot(target);
      segment.angle(targetToEndpoint.heading());
      segment.updateEndpoint();

      handleDragCollisions(segment, target);
    }
  }

  private void handleDragCollisions(TentacleSegment segment, PVector pivot) {
    if (detectCollision(segment)) {
      float prevAngle = segment.angle();

      // Try rotating in both directions to find the minimum amount of rotation necessary.
      for (float a = 0; a < PI; a += radians(1)) {
        segment.angle(prevAngle + a);
        segment.updateEndpoint();

        if (!detectCollision(segment)) return;

        segment.angle(prevAngle - a);
        segment.updateEndpoint();

        if (!detectCollision(segment)) return;
      }

      // FIXME: Can I throw an exception here instead?
      println("No way to not collide!");
    }
  }
}
