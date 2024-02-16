
class InchTowardInstruction extends TentacleInstruction {
  private final float MAX_ANGLE_DELTA = radians(2);
  private final float ANGLE_DELTA_ERROR = radians(0.5);

  // Can't use enums inside inner class because they use static members.
  private final int PHASE_DETACH_TIP = 0;
  private final int PHASE_REATTACH_TIP = 1;
  private final int PHASE_TRAVERSE_TO_BASE = 2;

  protected Tentacle tentacle;
  protected List<TentacleSegment> segments;

  public int phase;
  public PVector direction;
  public int segmentIndex;

  public InchTowardInstruction(Tentacle tentacleArg) {
    tentacle = tentacleArg;
    segments = tentacle.segments();

    phase = PHASE_DETACH_TIP;
    direction = null;
    segmentIndex = 0;
  }

  public void step(int instructionIndex) {
    switch (phase) {
      case PHASE_DETACH_TIP:
        stepDetachTip();
        break;
      case PHASE_REATTACH_TIP:
        stepReattachTip();
        break;
      case PHASE_TRAVERSE_TO_BASE:
        stepTraverseToBase();
        break;
      default:
        println("Error: unexpected InchTowardInstruction phase. " + phase);
    }
  }

  private void stepDetachTip() {

    boolean isCurrSegmentComplete = true;

    TentacleSegment segmentA = segments.get(segmentIndex);
    TentacleSegment prevSegment = segments.get(segmentIndex - 1);

    if (segmentA.fixedRotationDirection == 0) {
      // This segment was never attached to a surface.
      segmentIndex--;
      if (segmentIndex <= 0) {
        isComplete = true;
      }
      return;
    }

    segmentA.isFixed = false;
    
    // First segment

    // Rotate 90° away from the surface.
    float angleDelta = min(getAngleBetween(segmentA.angle(), prevSegment.angle() - segmentA.fixedRotationDirection * PI/2), MAX_ANGLE_DELTA);
    if (angleDelta > ANGLE_DELTA_ERROR) {
      // Rotate all of them so that the relative rotations happening further down the tentacle are preserved.
      // Otherwise those rotations will overshoot and they will keep spinning until this one completes.
      tentacle.rotateSegmentsBy(segmentIndex, segments.size(), -segmentA.fixedRotationDirection * angleDelta);
      tentacle.updateSegmentPointsBaseToTip(segmentIndex, segments.size());

      isCurrSegmentComplete = false;
    }

    // Second segment

    if (segmentIndex + 1 < segments.size()) {
      TentacleSegment segmentB = segments.get(segmentIndex + 1);

      // Rotate 90° toward the surface.
      angleDelta = min(getAngleBetween(segmentB.angle(), segmentA.angle() + segmentB.fixedRotationDirection * PI/2), MAX_ANGLE_DELTA * 2);
      if (angleDelta > ANGLE_DELTA_ERROR) {
        tentacle.rotateSegmentsBy(segmentIndex + 1, segments.size(), segmentB.fixedRotationDirection * angleDelta);
        tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());

        isCurrSegmentComplete = false;
      }

      // Third segment

      if (segmentIndex + 2 < segments.size()) {
        TentacleSegment segmentC = segments.get(segmentIndex + 2);

        // Also rotate 90° toward the surface.
        angleDelta = min(getAngleBetween(segmentC.angle(), segmentB.angle() + segmentC.fixedRotationDirection * PI/2), MAX_ANGLE_DELTA);
        if (angleDelta > ANGLE_DELTA_ERROR) {
          tentacle.rotateSegmentsBy(segmentIndex + 2, segments.size(), segmentC.fixedRotationDirection * angleDelta);
          tentacle.updateSegmentPointsBaseToTip(segmentIndex + 2, segments.size());

          isCurrSegmentComplete = false;
        }
      }
    }

    if (isCurrSegmentComplete) {
      // Only the three segments nearest the tip are handled in this phase.
      if (segmentIndex > segments.size() - 3) {
        segmentIndex--;
        if (segmentIndex <= 0) {
          isComplete = true;
        }
      } else {
        phase = PHASE_REATTACH_TIP;
      }
    }
  }

  private void stepReattachTip() {
    TentacleSegment tipSegment = segments.get(segments.size() - 1);

    // Now the tentacle is in a box shape. Rotate the second segment clockwise
    // and the third segment counter-clockwise until the tip touches the surface.
    TentacleSegment segmentA = segments.get(segmentIndex);
    TentacleSegment segmentB = segments.get(segmentIndex + 1);
    TentacleSegment segmentC = segments.get(segmentIndex + 2);

    float prevRotationB = segmentB.angle();
    float prevRotationC = segmentC.angle();

    tentacle.rotateSegmentsBy(segmentIndex + 1, segments.size(), segmentB.fixedRotationDirection * MAX_ANGLE_DELTA);
    tentacle.rotateSegmentsBy(segmentIndex + 2, segments.size(), -segmentC.fixedRotationDirection * MAX_ANGLE_DELTA);
    tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());

    if (tentacle.detectCollision(tipSegment)) {
      tipSegment.isFixed = true;
      tipSegment.fixedRotationDirection = segmentB.fixedRotationDirection;

      // Rotate 1° at a time until collision detected.
      float prevAngleB = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      float prevAngleC = 0;
      for (float a = 0; a < MAX_ANGLE_DELTA; a += radians(1)) {
        tentacle.setSegmentsAngle(segmentIndex + 1, segments.size(), prevRotationB + segmentB.fixedRotationDirection * a);
        tentacle.setSegmentsAngle(segmentIndex + 2, segments.size(), prevRotationC - segmentC.fixedRotationDirection * a);
        tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());
        
        if (tentacle.detectCollision(tipSegment)) {
          break;
        }
        
        prevAngleB = segmentB.angle();
        prevAngleC = segmentC.angle();
      }

      segmentB.angle(prevAngleB);
      segmentB.updateEndpoint();

      segmentC.angle(prevAngleC);
      segmentC.updateEndpoint();

      segmentIndex--;
      if (segmentIndex <= 0) {
        isComplete = true;
      }
      phase = PHASE_TRAVERSE_TO_BASE;
    }

    // TODO: If the tentacle is on an edge, the tip may not be able to find a surface to touch. Handle it.
  }

  private void stepTraverseToBase() {
    // TODO: Handle situations where the segment attaching and detaching are happening at different rates.

    boolean isCurrSegmentComplete = true;

    if (segmentIndex > 0) {
      TentacleSegment segmentA = segments.get(segmentIndex);
      TentacleSegment prevSegment = segments.get(segmentIndex - 1);

      if (segmentA.fixedRotationDirection == 0) {
        // This segment was never attached to a surface.
        segmentIndex--;
        if (segmentIndex <= 0) {
          isComplete = true;
        }
        return;
      }

      segmentA.isFixed = false;

      // Rotate 90° away from the surface.
      float angleDelta = min(getAngleBetween(segmentA.angle(), prevSegment.angle() - segmentA.fixedRotationDirection * PI/2), MAX_ANGLE_DELTA);
      if (angleDelta > ANGLE_DELTA_ERROR) {
        segmentA.angle(segmentA.angle() - segmentA.fixedRotationDirection * angleDelta);
        segmentA.updateEndpoint();
      } else {
        segmentIndex--;
      }
    }

    // Rotate toward the surface until it collides.
    // TODO: What if it doesn't collide, like if there's a gap in the floor there?
    int firstFixedSegmentIndex = tentacle.getFirstFixedSegmentIndex(segmentIndex + 1);
    TentacleSegment firstFixedSegment = segments.get(firstFixedSegmentIndex);

    float prevRotation = firstFixedSegment.angle();

    // TODO: Weed out hard-coded rotation directions.
    
    // Rotate in the reverse direction because it's rotating around the endpoint, not the pivot.
    firstFixedSegment.angle(firstFixedSegment.angle() - firstFixedSegment.fixedRotationDirection * MAX_ANGLE_DELTA);
    firstFixedSegment.updatePivot();

    if (tentacle.detectPivotCollision(firstFixedSegment)) {
      TentacleSegment beforeFirstFixedSegment = segments.get(firstFixedSegmentIndex - 1);
      beforeFirstFixedSegment.isFixed = true;
      beforeFirstFixedSegment.fixedRotationDirection = firstFixedSegment.fixedRotationDirection;

      // Rotate 1° at a time until collision detected.
      float prevAngle = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      for (float a = 0; a < MAX_ANGLE_DELTA; a += radians(1)) {
        // Rotate in the reverse direction because it's rotating around the endpoint, not the pivot.
        firstFixedSegment.angle(prevRotation - firstFixedSegment.fixedRotationDirection * a);
        firstFixedSegment.updatePivot();
        
        if (tentacle.detectPivotCollision(firstFixedSegment)) {
          break;
        }
        
        prevAngle = firstFixedSegment.angle();
      }
      
      firstFixedSegment.angle(prevAngle);
      firstFixedSegment.updatePivot();
    } else {
      isCurrSegmentComplete = false;
    }

    PVector firstFixedSegmentEndpoint = firstFixedSegment.endpoint();
    if (segmentIndex < firstFixedSegmentIndex - 1) {
      for (int iteration = 0; iteration < 200; iteration++) {
        tentacle.simpleIk(segmentIndex, firstFixedSegmentIndex - 1);
      }
    }
    //firstFixedSegment.endpoint(firstFixedSegmentEndpoint);
    //firstFixedSegment.updatePivot();
    tentacle.updateSegmentPointsTipToBase(firstFixedSegmentIndex, segmentIndex);

    // TODO: When does the instruction end?
  }

  private float getAngleBetween(float a, float b) {
    return PI - abs(abs(b - a) % (2 * PI) - PI);
  }
}