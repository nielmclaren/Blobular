
class PointAtInstruction extends TentacleInstruction {
  protected Tentacle tentacle;
  protected List<TentacleSegment> segments;

  public int rotationDirection;
  public PVector targetDirection;
  public PVector contactTargetDirection;
  public int segmentIndex;
  
  PointAtInstruction(Tentacle tentacleArg) {
    tentacle = tentacleArg;
    segments = tentacle.segments();

    rotationDirection = 0;
    targetDirection = null;
    contactTargetDirection = null;
    segmentIndex = 0;
  }

  public void step(int instructionIndex) {
    TentacleSegment segment = segments.get(segmentIndex);
    PVector pivot = segment.pivot();
    PVector segmentVector = segment.getVector();
    
    float prevRotation = segment.angle();
    float angleError = radians(0.5);
    float angleDelta = min(PVector.angleBetween(segmentVector, targetDirection), segment.maxAngleDelta);
    
    int angleSign;
    if (rotationDirection == 0) {
      angleSign = RotationDirection.getRotationSign(segmentVector, targetDirection);
    } else {
      angleSign = rotationDirection;
    }
    
    segment.angle(segment.angle() + angleSign * angleDelta);
    segment.updateEndpoint();
    
    boolean collided = tentacle.handleCollisions(segment, prevRotation, angleSign, angleDelta);
    if (collided) {
      // Force remaining segments to rotate in the same direction as the segment that collided.
      rotationDirection = angleSign;
      segment.isFixed = true;
      segment.fixedRotationDirection = angleSign;
    }
    
    tentacle.dragRemainingSegments(segmentIndex + 1);
    
    // If this segment is in position then move onto next segment for the next iteration.
    angleDelta = min(PVector.angleBetween(segment.getVector(), targetDirection), segment.maxAngleDelta);
    if (collided || angleDelta <= angleError) {
      segmentIndex++;
      if (segmentIndex >= segments.size()) {
        isComplete = true;
      } else {
        tentacle.cancelOlderPointAtInstructions(instructionIndex, segmentIndex);
        tentacle.tryToTriggerContactInstruction(this);
      }
    }
  }
}
