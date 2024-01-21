
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

    TentacleSegment parent = null;
    PVector currPos = new PVector();
    
    for (int i = 0;  i < numSegments; i++) {
      float segmentLength = map(i, 0, numSegments, baseSegmentLength, tipSegmentLength);
      TentacleSegment segment = new TentacleSegment(
      parent,
      segmentLength,
      baseAngle + radians(30) * i,
      radians(20));

      segments.add(segment);
      currPos.add(segment.getVector());

      parent = segment;
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

  public void step(int count) {
    for (int i = 0; i < count; i++) {
      step();
    }
  }

  public void step() {
    for (TentacleInstruction instruction : instructions) {
      TentacleSegment segment = segments.get(instruction.segmentIndex);
      PVector pivot = getPivot(instruction.segmentIndex);
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
      
      if (detectCollision(segment)) {
        break;
      }
      
      prevAngle = segment.angle();
      }
      
      segment.angle(prevAngle);
      
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

  private void dragRemainingSegments(int startSegmentIndex) {
    for (int i = startSegmentIndex; i < segments.size(); i++) {
      PVector pivot;
      if (i > 0) {
      TentacleSegment prevSegment = segments.get(i - 1);
      pivot = new PVector(prevSegment.endpointX(), prevSegment.endpointY());
      } else {
      pivot = new PVector(0, 0);
      }
    
      TentacleSegment segment = segments.get(i);
      PVector endpoint = new PVector(segment.endpointX(), segment.endpointY());
      PVector pivotToEndpoint = PVector.sub(endpoint, pivot);
      
      segment.angle(pivotToEndpoint.heading());

      handleDragCollisions(segment, pivot);
    }
  }

  private void handleDragCollisions(TentacleSegment segment, PVector pivot) {
    if (detectCollision(segment)) {
      float prevAngle = segment.angle();

      // Try rotating in both directions to find the minimum amount of rotation necessary.
      for (float a = 0; a < PI; a += radians(1)) {
      segment.angle(prevAngle + a);

      if (!detectCollision(segment)) return;

      segment.angle(prevAngle - a);

      if (!detectCollision(segment)) return;
      }

      // FIXME: Can I throw an exception here instead?
      println("No way to not collide!");
    }
  }

  // TODO: Is getPivot() still needed?
  private PVector getPivot(int segmentIndex) {
  if (segmentIndex > 0) {
    TentacleSegment prevSegment = segments.get(segmentIndex - 1);
    return new PVector(prevSegment.endpointX(), prevSegment.endpointY());
  } else {
    return new PVector(0, 0);
  }
}

}
