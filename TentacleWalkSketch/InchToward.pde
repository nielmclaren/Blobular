
class InchToward {
  protected Tentacle tentacle;
  protected List<TentacleSegment> segments;

  InchToward(Tentacle tentacleArg) {
      tentacle = tentacleArg;
      segments = tentacle.segments();
  }

  public void step(InchTowardInstruction instruction) {
    switch (instruction.phase) {
      case 0:
        inchTowardPhase0(instruction);
        break;
      case 1:
        inchTowardPhase1(instruction);
        break;
      case 2:
        inchTowardPhase2(instruction);
        break;
      default:
        println("Error: unexpected InchTowardInstruction phase. " + instruction.phase);
    }
  }

  private void inchTowardPhase0(InchTowardInstruction instruction) {
    float angleError = radians(0.5);

    boolean isCurrSegmentComplete = true;

    TentacleSegment segmentA = segments.get(instruction.segmentIndex);
    TentacleSegment prevSegment = segments.get(instruction.segmentIndex - 1);

    if (segmentA.fixedRotationDirection == 0) {
      // This segment was never attached to a surface.
      instruction.segmentIndex--;
      if (instruction.segmentIndex <= 0) {
        instruction.isComplete = true;
      }
      return;
    }

    segmentA.isFixed = false;
    
    // First segment

    // Rotate 90° away from the surface.
    PVector targetVector = prevSegment.getVector();
    targetVector.normalize();
    targetVector.rotate(-segmentA.fixedRotationDirection * PI/2);
    float angleDelta = min(PVector.angleBetween(segmentA.getVector(), targetVector), segmentA.maxAngleDelta);
    if (angleDelta > angleError) {
      // Rotate all of them so that the relative rotations happening further down the tentacle are preserved.
      // Otherwise those rotations will overshoot and they will keep spinning until this one completes.
      tentacle.rotateSegmentsBy(instruction.segmentIndex, segments.size(), -segmentA.fixedRotationDirection * angleDelta);
      //segmentA.angle(segmentA.angle() - segmentA.fixedRotationDirection * angleDelta);
      //segmentA.updateEndpoint();

      isCurrSegmentComplete = false;
    }

    if (instruction.segmentIndex < segments.size()) {
      tentacle.updateSegmentPointsBaseToTip(instruction.segmentIndex, segments.size());
    }

    // Second segment

    if (instruction.segmentIndex + 1 < segments.size()) {
      TentacleSegment segmentB = segments.get(instruction.segmentIndex + 1);

      // Rotate 90° toward the surface.
      targetVector = segmentA.getVector();
      targetVector.normalize();
      targetVector.rotate(segmentB.fixedRotationDirection * PI / 2);
      angleDelta = min(PVector.angleBetween(segmentB.getVector(), targetVector), segmentB.maxAngleDelta * 2);

      if (angleDelta > angleError) {
        //println(instruction.segmentIndex + " " + round(degrees(targetVector.heading())) + " " + round(degrees(segmentB.angle())) + " " + round(degrees(angleDelta)) + " " + round(degrees(segmentB.angle() + segmentB.fixedRotationDirection * angleDelta)));

        // Rotate all of them so that the relative rotations happening further down the tentacle are preserved.
        // Otherwise those rotations will overshoot and they will keep spinning until this one completes.
        tentacle.rotateSegmentsBy(instruction.segmentIndex + 1, segments.size(), segmentB.fixedRotationDirection * angleDelta);
        //segmentB.angle(segmentB.angle() + segmentB.fixedRotationDirection * angleDelta);
        //segmentB.updateEndpoint();

        isCurrSegmentComplete = false;
      }

      if (instruction.segmentIndex + 1 < segments.size()) {
        tentacle.updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());
      }

      // Third segment

      if (instruction.segmentIndex + 2 < segments.size()) {
        TentacleSegment segmentC = segments.get(instruction.segmentIndex + 2);

        // Rotate 90° toward the surface.
        targetVector = segmentB.getVector();
        targetVector.normalize();
        targetVector.rotate(segmentC.fixedRotationDirection * PI / 2);
        angleDelta = min(PVector.angleBetween(segmentC.getVector(), targetVector), segmentC.maxAngleDelta);

        if (angleDelta > angleError) {
          // Rotate all of them so that the relative rotations happening further down the tentacle are preserved.
          // Otherwise those rotations will overshoot and they will keep spinning until this one completes.
          tentacle.rotateSegmentsBy(instruction.segmentIndex + 2, segments.size(), segmentC.fixedRotationDirection * angleDelta);
          //segmentC.angle(segmentC.angle() + segmentC.fixedRotationDirection * angleDelta);
          //segmentC.updateEndpoint();

          isCurrSegmentComplete = false;
        }

        if (instruction.segmentIndex + 2 < segments.size()) {
          tentacle.updateSegmentPointsBaseToTip(instruction.segmentIndex + 2, segments.size());
        }
      }
    }

    if (isCurrSegmentComplete) {
      if (instruction.segmentIndex > segments.size() - 3) {
        instruction.segmentIndex--;
        if (instruction.segmentIndex <= 0) {
          instruction.isComplete = true;
        }
      } else {
        instruction.phase = 1;
      }
    }
  }

  private void inchTowardPhase1(InchTowardInstruction instruction) {
    TentacleSegment tipSegment = segments.get(segments.size() - 1);

    // Now the tentacle is in a box shape. Rotate the second segment clockwise
    // and the third segment counter-clockwise until the tip touches the surface.
    TentacleSegment segmentA2 = segments.get(instruction.segmentIndex);
    TentacleSegment segmentB2 = segments.get(instruction.segmentIndex + 1);
    TentacleSegment segmentC2 = segments.get(instruction.segmentIndex + 2);

    float prevRotationB = segmentB2.angle();
    float prevRotationC = segmentC2.angle();

    tentacle.rotateSegmentsBy(instruction.segmentIndex + 1, segments.size(), segmentB2.fixedRotationDirection * segmentB2.maxAngleDelta);
    tentacle.rotateSegmentsBy(instruction.segmentIndex + 2, segments.size(), -segmentC2.fixedRotationDirection * segmentC2.maxAngleDelta);
    tentacle.updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());

    if (tentacle.detectCollision(tipSegment)) {
      tipSegment.isFixed = true;
      tipSegment.fixedRotationDirection = segmentB2.fixedRotationDirection;

      // Rotate 1° at a time until collision detected.
      float prevAngleB = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      float prevAngleC = 0;
      // TODO: Don't track max angle delta for each segment separately. It leads to situations like this where
      // I need to iterate from 0 to two (potentially) different values of maxAngleDelta. Can add later if need.
      for (float a = 0; a < segmentB2.maxAngleDelta; a += radians(1)) {
        tentacle.setSegmentsAngle(instruction.segmentIndex + 1, segments.size(), prevRotationB + segmentB2.fixedRotationDirection * a);
        tentacle.setSegmentsAngle(instruction.segmentIndex + 2, segments.size(), prevRotationC - segmentC2.fixedRotationDirection * a);
        tentacle.updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());
        
        if (tentacle.detectCollision(tipSegment)) {
          break;
        }
        
        prevAngleB = segmentB2.angle();
        prevAngleC = segmentC2.angle();
      }

      segmentB2.angle(prevAngleB);
      segmentB2.updateEndpoint();

      segmentC2.angle(prevAngleC);
      segmentC2.updateEndpoint();

      instruction.segmentIndex--;
      if (instruction.segmentIndex <= 0) {
        instruction.isComplete = true;
      }
      instruction.phase = 2;
    }

    // TODO: If the tentacle is on an edge, the tip may not be able to find a surface to touch. Handle it.
  }

  private void inchTowardPhase2(InchTowardInstruction instruction) {
    // TODO: Handle situations where the segment attaching and detaching are happening at different rates.
    float angleError = radians(0.5);

    boolean isCurrSegmentComplete = true;

    if (instruction.segmentIndex > 0) {
      TentacleSegment segmentA = segments.get(instruction.segmentIndex);
      TentacleSegment prevSegment = segments.get(instruction.segmentIndex - 1);

      if (segmentA.fixedRotationDirection == 0) {
        // This segment was never attached to a surface.
        instruction.segmentIndex--;
        if (instruction.segmentIndex <= 0) {
          instruction.isComplete = true;
        }
        return;
      }

      segmentA.isFixed = false;

      // Rotate 90° away from the surface.
      PVector targetVector = prevSegment.getVector();
      targetVector.normalize();
      targetVector.rotate(-segmentA.fixedRotationDirection * PI/2);
      float angleDelta = min(PVector.angleBetween(segmentA.getVector(), targetVector), segmentA.maxAngleDelta);
      if (angleDelta > angleError) {
        segmentA.angle(segmentA.angle() - segmentA.fixedRotationDirection * angleDelta);
        segmentA.updateEndpoint();
      } else {
        instruction.segmentIndex--;
      }
    }

    // Rotate toward the surface until it collides.
    // TODO: What if it doesn't collide, like if there's a gap in the floor there?
    int firstFixedSegmentIndex = tentacle.getFirstFixedSegmentIndex(instruction.segmentIndex + 1);
    TentacleSegment firstFixedSegment = segments.get(firstFixedSegmentIndex);

    float prevRotation = firstFixedSegment.angle();

    // TODO: Weed out hard-coded rotation directions.
    
    // Rotate in the reverse direction because it's rotating around the endpoint, not the pivot.
    firstFixedSegment.angle(firstFixedSegment.angle() - firstFixedSegment.fixedRotationDirection * firstFixedSegment.maxAngleDelta);
    firstFixedSegment.updatePivot();

    if (tentacle.detectPivotCollision(firstFixedSegment)) {
      TentacleSegment beforeFirstFixedSegment = segments.get(firstFixedSegmentIndex - 1);
      beforeFirstFixedSegment.isFixed = true;
      beforeFirstFixedSegment.fixedRotationDirection = firstFixedSegment.fixedRotationDirection;

      // Rotate 1° at a time until collision detected.
      float prevAngle = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      for (float a = 0; a < firstFixedSegment.maxAngleDelta; a += radians(1)) {
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
    if (instruction.segmentIndex < firstFixedSegmentIndex - 1) {
      for (int iteration = 0; iteration < 200; iteration++) {
        tentacle.simpleIk(instruction.segmentIndex, firstFixedSegmentIndex - 1);
      }
    }
    //firstFixedSegment.endpoint(firstFixedSegmentEndpoint);
    //firstFixedSegment.updatePivot();
    tentacle.updateSegmentPointsTipToBase(firstFixedSegmentIndex, instruction.segmentIndex);

    // TODO: When does the instruction end?
  }
}