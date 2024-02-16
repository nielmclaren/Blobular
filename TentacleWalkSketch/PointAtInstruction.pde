
/**
 * Start at the base and rotate segments one at a time until they point
 * in a particular direction.
 * 
 * Option to trigger a new PointAtInstruction when half-way down the
 * list of segments.
 */
class PointAtInstruction extends TentacleInstruction {
  private final float MAX_ANGLE_DELTA = radians(2);

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
    TentacleSegment segment = segments.get(this.segmentIndex);
    PVector pivot = segment.pivot();
    PVector segmentVector = segment.getVector();
    
    float prevRotation = segment.angle();
    float angleError = radians(0.5);
    float angleDelta = min(PVector.angleBetween(segmentVector, this.targetDirection), MAX_ANGLE_DELTA);
    
    int angleSign;
    if (this.rotationDirection == 0) {
      angleSign = RotationDirection.getRotationSign(segmentVector, this.targetDirection);
    } else {
      angleSign = this.rotationDirection;
    }
    
    segment.angle(segment.angle() + angleSign * angleDelta);
    segment.updateEndpoint();
    
    boolean collided = handleCollisions(segment, prevRotation, angleSign, angleDelta);
    if (collided) {
      // Force remaining segments to rotate in the same direction as the segment that collided.
      this.rotationDirection = angleSign;
      segment.isFixed = true;
      segment.fixedRotationDirection = angleSign;
    }
    
    tentacle.dragRemainingSegments(this.segmentIndex + 1);
    
    // If this segment is in position then move onto next segment for the next iteration.
    angleDelta = min(PVector.angleBetween(segment.getVector(), this.targetDirection), MAX_ANGLE_DELTA);
    if (collided || angleDelta <= angleError) {
      this.segmentIndex++;
      if (this.segmentIndex >= segments.size()) {
        this.isComplete = true;
      } else {
        tentacle.cancelOlderPointAtInstructions(instructionIndex, this.segmentIndex);
        tentacle.tryToTriggerContactInstruction(this);
      }
    }
  }

  private boolean handleCollisions(TentacleSegment segment, float prevRotation, int angleSign, float angleDelta) {
    // FIXME: Assumes segment was not originally in a collided state.
    if (tentacle.detectCollision(segment)) {
      segment.isFixed = true;
      segment.fixedRotationDirection = angleSign;

      // Rotate 1° at a time until collision detected.
      float prevAngle = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      for (float a = 0; a < angleDelta; a += radians(1)) {
        segment.angle(prevRotation + angleSign * a);
        segment.updateEndpoint();
        
        if (tentacle.detectCollision(segment)) {
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
}
