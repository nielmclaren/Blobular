
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

    TentacleSegment segment0 = segments.get(segmentIndex);
    TentacleSegment prevSegment = segments.get(segmentIndex - 1);

    if (segment0.fixedRotationDirection == 0) {
      // This segment was never attached to a surface.
      segmentIndex--;
      if (segmentIndex <= 0) {
        isComplete = true;
      }
      return;
    }

    segment0.isFixed = false;
    
    // First segment

    // Rotate 90° away from the surface.
    float targetAngle = prevSegment.angle() - segment0.fixedRotationDirection * PI/2;
    float angleDelta = min(getAngleBetween(segment0.angle(), targetAngle), MAX_ANGLE_DELTA);
    if (angleDelta > ANGLE_DELTA_ERROR) {
      // Rotate all of them so that the relative rotations happening further down the tentacle are preserved.
      // Otherwise those rotations will overshoot and they will keep spinning until this one completes.
      tentacle.rotateSegmentsBy(segmentIndex, segments.size(), -segment0.fixedRotationDirection * angleDelta);
      tentacle.updateSegmentPointsBaseToTip(segmentIndex, segments.size());

      isCurrSegmentComplete = false;
    }

    // Second segment

    if (segmentIndex + 1 < segments.size()) {
      TentacleSegment segment1 = segments.get(segmentIndex + 1);

      // Rotate 90° toward the surface.
      targetAngle = segment0.angle() + segment1.fixedRotationDirection * PI/2;
      angleDelta = min(getAngleBetween(segment1.angle(), targetAngle), MAX_ANGLE_DELTA * 2);
      if (angleDelta > ANGLE_DELTA_ERROR) {
        tentacle.rotateSegmentsBy(segmentIndex + 1, segments.size(), segment1.fixedRotationDirection * angleDelta);
        tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());

        isCurrSegmentComplete = false;
      }

      // Third segment

      if (segmentIndex + 2 < segments.size()) {
        TentacleSegment segment2 = segments.get(segmentIndex + 2);

        // Also rotate 90° toward the surface.
        targetAngle = segment1.angle() + segment2.fixedRotationDirection * PI/2;
        angleDelta = min(getAngleBetween(segment2.angle(), targetAngle), MAX_ANGLE_DELTA);
        if (angleDelta > ANGLE_DELTA_ERROR) {
          tentacle.rotateSegmentsBy(segmentIndex + 2, segments.size(), segment2.fixedRotationDirection * angleDelta);
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

    // Now the tentacle is in a box shape. Rotate segment1 clockwise
    // and segment2 counter-clockwise until the tip touches the surface.
    TentacleSegment segment1 = segments.get(segmentIndex + 1);
    TentacleSegment segment2 = segments.get(segmentIndex + 2);

    float originalAngle1 = segment1.angle();
    float originalAngle2 = segment2.angle();

    tentacle.rotateSegmentsBy(segmentIndex + 1, segments.size(), segment1.fixedRotationDirection * MAX_ANGLE_DELTA);
    tentacle.rotateSegmentsBy(segmentIndex + 2, segments.size(), -segment2.fixedRotationDirection * MAX_ANGLE_DELTA);
    tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());

    if (tentacle.detectCollision(tipSegment)) {
      tipSegment.isFixed = true;
      tipSegment.fixedRotationDirection = segment1.fixedRotationDirection;

      // Rotate segment1 and segment2 1° at a time until collision detected.
      float prevAngle1 = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      float prevAngle2 = 0;
      for (float a = 0; a < MAX_ANGLE_DELTA; a += radians(1)) {
        tentacle.setSegmentsAngle(segmentIndex + 1, segments.size(), originalAngle1 + segment1.fixedRotationDirection * a);
        tentacle.setSegmentsAngle(segmentIndex + 2, segments.size(), originalAngle2 - segment2.fixedRotationDirection * a);
        tentacle.updateSegmentPointsBaseToTip(segmentIndex + 1, segments.size());
        
        if (tentacle.detectCollision(tipSegment)) {
          break;
        }
        
        prevAngle1 = segment1.angle();
        prevAngle2 = segment2.angle();
      }

      segment1.angle(prevAngle1);
      segment1.updateEndpoint();

      segment2.angle(prevAngle2);
      segment2.updateEndpoint();

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

    TentacleSegment segment0 = segments.get(segmentIndex);

    if (segmentIndex > 0) {
      TentacleSegment prevSegment = segments.get(segmentIndex - 1);

      if (segment0.fixedRotationDirection == 0) {
        // This segment was never attached to a surface.
        segmentIndex--;
        if (segmentIndex <= 0) {
          isComplete = true;
        }
        return;
      }

      segment0.isFixed = false;

      // Rotate 90° away from the surface.
      float targetAngle = prevSegment.angle() - segment0.fixedRotationDirection * PI/2;
      float angleDelta = min(getAngleBetween(segment0.angle(), targetAngle), MAX_ANGLE_DELTA);
      if (angleDelta > ANGLE_DELTA_ERROR) {
        segment0.angle(segment0.angle() - segment0.fixedRotationDirection * angleDelta);
        segment0.updateEndpoint();
      } else {
        segmentIndex--;
      }
    }

    // Rotate `firstFixedSegment` around the endpoint toward the surface until the pivot collides.
    // TODO: What if it doesn't collide, like if there's a gap in the floor there?
    int firstFixedSegmentIndex = tentacle.getFirstFixedSegmentIndex(segmentIndex + 1);
    TentacleSegment firstFixedSegment = segments.get(firstFixedSegmentIndex);

    if (firstFixedSegmentIndex - segmentIndex > 3) {
      println("Got enough segments to start re-attaching segments.");
      float originalAngle = firstFixedSegment.angle();

      // TODO: Weed out hard-coded rotation directions.
      
      // Rotate in the reverse direction because it's rotating around the endpoint, not the pivot.
      firstFixedSegment.angle(firstFixedSegment.angle() - firstFixedSegment.fixedRotationDirection * MAX_ANGLE_DELTA);
      firstFixedSegment.updatePivot();

      if (tentacle.detectPivotCollision(firstFixedSegment)) {
        TentacleSegment beforeFirstFixedSegment = segments.get(firstFixedSegmentIndex - 1);
        beforeFirstFixedSegment.isFixed = true;
        beforeFirstFixedSegment.fixedRotationDirection = firstFixedSegment.fixedRotationDirection;

        // Rotate in the reverse direction because it's rotating around the endpoint, not the pivot.
        float a = getAngleJustBeforeCollision(firstFixedSegment, originalAngle, -firstFixedSegment.fixedRotationDirection);
        
        firstFixedSegment.angle(a);
        firstFixedSegment.updatePivot();
      }
    }

    // Make an arc out of the segments between segmentIndex and firstFixedSegmentIndex. //<>// //<>//
    
    if (firstFixedSegmentIndex - segmentIndex == 2) {
      println("firstFixedSegmentIndex - segmentIndex == 2");
      // Only one segment between the detaching and attaching segments. Just point it the
      // right direction and hope for the best.
      PVector h = PVector.sub(firstFixedSegment.pivot(), segment0.endpoint());
      TentacleSegment segment = segments.get(segmentIndex + 1);
      segment.angle(h.heading());
      // TODO: Prevent this case from happening because there's no way to make a single segment
      // fit the distance between the detaching and attaching segments.
    } else if (firstFixedSegmentIndex - segmentIndex == 3) {
      println("firstFixedSegmentIndex - segmentIndex == 3");
      // Triangle case.
      TentacleSegment a = segments.get(segmentIndex + 1);
      TentacleSegment b = segments.get(segmentIndex + 2);
      PVector c = PVector.sub(firstFixedSegment.pivot(), segment0.endpoint());
      if (c.mag() >= a.length() + b.length()) {
        // The segments cannot cover the required distance. Just point them in the
        // right direction and hope for the best.
        println("got c > a + b");
        a.angle(c.heading());
        b.angle(c.heading());
      } else {
        // Angle B = acos( (a^2 + c^2 - b^2) / (2ac) )
        float B = acos( (a.length() * a.length()  +  c.mag() * c.mag() - b.length() * b.length()) / (2 * a.length() * c.mag()) );
        println((a.length() * a.length()  +  c.mag() * c.mag() - b.length() * b.length()) / (2 * a.length() * c.mag()));
        if (Float.isNaN(B)) {
          println("gotNaN");
        }
        a.angle(c.heading() - B);
        // Angle C = acos( (a^2 + b^2 - c^2) / (2ab) )
        float C = acos( (a.length() * a.length()  +  b.length() * b.length()  -  c.mag() * c.mag()) / (2 * a.length() * b.length()) );
        b.angle(a.angle() + PI - C);
      }
    } else {
      println("firstFixedSegmentIndex - segmentIndex >= 4");

      tentacle.simpleIkBaseToTip(segmentIndex + 1, firstFixedSegmentIndex - 1);
    }

    //tentacle.updateSegmentPointsTipToBase(firstFixedSegmentIndex, segmentIndex);
    tentacle.updateSegmentPointsBaseToTip(segmentIndex, firstFixedSegmentIndex);

    // TODO: When does the instruction end?
  }

  private float getAngleJustBeforeCollision(TentacleSegment segment, float originalAngle, int rotationDirection) {
    // Rotate 1° at a time until collision detected.
    float prevAngle = 0;
    for (float a = 0; a < MAX_ANGLE_DELTA; a += radians(1)) {
      segment.angle(originalAngle + rotationDirection * a);
      segment.updatePivot();
      
      if (tentacle.detectPivotCollision(segment)) {
        break;
      }
      
      prevAngle = segment.angle();
    }
    return prevAngle;
  }

  private float getAngleBetween(float a, float b) {
    return PI - abs(abs(b - a) % (2 * PI) - PI);
  }
}
