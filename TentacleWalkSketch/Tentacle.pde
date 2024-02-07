
// The tentacle origin is at 0, 0. The tentacle is base is the position of the first
// segment's pivot, which may or may not match the tentacle origin.
public class Tentacle {
  protected List<TentacleSegment> segments;
  protected List<TentacleInstruction> instructions;

  public Tentacle() {
    segments = new ArrayList<TentacleSegment>();
    instructions = new ArrayList<TentacleInstruction>();

    initSegments();
  }

  private void initSegments() {
    float baseSegmentLength = 40;
    float tipSegmentLength = 20;
    float baseAngle = radians(10);
    int numSegments = 8;

    PVector currPos = new PVector();
    
    for (int i = 0;  i < numSegments; i++) {
      float segmentLength = map(i, 0, numSegments - 1, baseSegmentLength, tipSegmentLength);
      TentacleSegment segment = new TentacleSegment(
        segmentLength,
        baseAngle + radians(3) * i,
        radians(5));

      segment.pivot(currPos);
      segment.updateEndpoint();

      currPos.add(segment.getVector());

      segments.add(segment);
    }
  }

  public List<TentacleSegment> segments() {
    // TODO: Protect this accessor?
    return segments;
  }

  public void pointTo(PVector direction) {
    TentacleInstruction instruction = new TentacleInstruction();
    instruction.targetDirection = direction.copy();
    instruction.targetDirection.normalize();
    instructions.add(instruction);
  }

  public void recoveryAndContact(PVector recoveryDirection, PVector contactDirection) {
    TentacleInstruction instruction = new TentacleInstruction();
    instruction.targetDirection = recoveryDirection.copy();
    instruction.targetDirection.normalize();
    instruction.contactTargetDirection = contactDirection.copy();
    instruction.contactTargetDirection.normalize();
    instructions.add(instruction);
  }

  public void inchToward(PVector direction) {
    InchTowardTentacleInstruction instruction = new InchTowardTentacleInstruction();
    instruction.segmentIndex = segments.size() - 1;
    instruction.direction = direction.copy();
    instructions.add(instruction);
  }

  public void move(float x, float y) {
    // Shift all segments in the opposite direction.
    for (TentacleSegment segment : segments) {
      segment.shift(-x, -y);
    }

    ikBaseToShiftedOrigin();
  }

  public boolean hasFixedSegment() {
    for (TentacleSegment segment : segments) {
      if (segment.isFixed) {
        return true;
      }
    }
    return false;
  }

  public boolean hasInstruction() {
    return instructions.size() > 0;
  }

  private void ikBaseToShiftedOrigin() {
    int ikStartIndex = getIkStartIndex();
    int firstFixedSegmentIndex = ikStartIndex + 1;
    PVector firstFixedSegmentEndpoint = firstFixedSegmentIndex < segments.size() ? segments.get(firstFixedSegmentIndex).endpoint() : null;

    // `getIkStartIndex()` may include some fixed segments so set them all to unfixed.
    setSegmentsIsFixed(0, min(firstFixedSegmentIndex, segments.size()), false, 0);

    // TODO: Improve iteration. I.e., check error value and break early.
    for (int iteration = 0; iteration < 20; iteration++) {
      simpleIk(0, min(firstFixedSegmentIndex, segments.size() - 1));
    }

    if (firstFixedSegmentIndex < segments.size()) {
      // Put the first fixed segment's endpoint back to where it started.
      TentacleSegment firstFixedSegment = segments.get(firstFixedSegmentIndex);
      firstFixedSegment.endpoint(firstFixedSegmentEndpoint);
      firstFixedSegment.updatePivot();

      updateSegmentPointsTipToBase(firstFixedSegmentIndex, 0);
    }
  }

  private int getIkStartIndex() {
    // The segments from the base up to but not including the first fixed segment
    // will be able to move toward the new base via ik.
    int fixedSegmentIndex = getFirstFixedSegmentIndex();
    int unfixedSegmentIndex;
    if (fixedSegmentIndex < 0) {
      // No segments are fixed so they can all move toward the new origin.
      return segments.size() - 1;
    } else if (fixedSegmentIndex == 0) {
      // First segment is fixed so start from there.
      unfixedSegmentIndex = 0;
    } else {
      // The last unfixed segment before the first fixed segment.
      unfixedSegmentIndex = fixedSegmentIndex - 1;
    }

    // Keep adding segments until there is enough tentacle length to
    // cover the distance to the tentacle origin.
    int ikStartIndex;
    for (ikStartIndex = unfixedSegmentIndex; ikStartIndex < segments.size() - 1; ikStartIndex++) {
      TentacleSegment segment = segments.get(ikStartIndex);
      TentacleSegment nextSegment = segments.get(ikStartIndex + 1);
      float distToTarget = nextSegment.endpoint().mag();
      float availableLength = getLengthBetweenIncl(0, ikStartIndex + 1);

      if (availableLength >= distToTarget) {
        break;
      }
    }

    return ikStartIndex;
  }

  private void setSegmentsIsFixed(int startIndex, int endIndex, boolean v, int rotationDirection) {
    for (int i = startIndex; i < endIndex; i++) {
      TentacleSegment segment = segments.get(i);
      segment.isFixed = v;
      segment.fixedRotationDirection = rotationDirection;
    }
  }

  private int getFirstFixedSegmentIndex() {
    return getFirstFixedSegmentIndex(0);
  }

  private int getFirstFixedSegmentIndex(int startIndex) {
    for (int i = startIndex; i < segments.size(); i++) {
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

  // Rotate segments to move the first segment's pivot (the tentacle base) to the origin.
  // Includes `startIndex` and `endIndex`.
  private void simpleIk(int startIndex, int endIndex) {
    assert(startIndex >= 0);
    assert(endIndex < segments.size());
    assert(startIndex < endIndex);

    for (int i = startIndex; i <= endIndex; i++) {
      PVector target;
      if (i <= 0) {
        // The first segment's target is the origin.
        target = new PVector();
      } else {
        TentacleSegment prevSegment = segments.get(i - 1);
        target = prevSegment.endpoint();
      }

      TentacleSegment segment = segments.get(i);
      PVector targetToEndpoint = PVector.sub(segment.endpoint(), target);

      // Rotate the current segment to point its pivot at the previous segment's endpoint.
      // (Because we're going tip to base, the segment points away from the previous segment's endpoint.)
      segment.angle(targetToEndpoint.heading());

      // Move thecurrent segment so that its pivot is at the previous segment's endpoint.
      segment.pivot(target);

      segment.updateEndpoint();
    }
  }

  public void step(int count) {
    for (int i = 0; i < count; i++) {
      step();
    }
  }

  public void step() {
    for (int i = instructions.size() - 1; i >= 0; i--) {
      TentacleInstruction instruction = instructions.get(i);

      if (instruction.isComplete) {
        // It is possible to encounter completed instructions here because of `cancelOlderInstructions()`.
        continue;
      }

      evaluateInstructionAt(i);
    }

    instructions.removeIf(instruction -> instruction.isComplete);
  }

  private void evaluateInstructionAt(int instructionIndex) {
    TentacleInstruction instruction = instructions.get(instructionIndex);
    if (instruction instanceof InchTowardTentacleInstruction) {
      evaluateInchTowardInstruction((InchTowardTentacleInstruction) instruction);
      return;
    }

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
      // Force remaining segments to rotate in the same direction as the segment that collided.
      instruction.rotationDirection = angleSign;
      segment.isFixed = true;
      segment.fixedRotationDirection = angleSign;
    }
    
    dragRemainingSegments(instruction.segmentIndex + 1);
    
    // If this segment is in position then move onto next segment for the next iteration.
    angleDelta = min(PVector.angleBetween(segment.getVector(), instruction.targetDirection), segment.maxAngleDelta);
    if (collided || angleDelta <= angleError) {
      instruction.segmentIndex++;
      if (instruction.segmentIndex >= segments.size()) {
        instruction.isComplete = true;
      } else {
        cancelOlderInstructions(instructionIndex, instruction.segmentIndex);
        tryToTriggerContactInstruction(instruction);
      }
    }
  }

  private void evaluateInchTowardInstruction(InchTowardTentacleInstruction instruction) {
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
        println("Error: unexpected InchTowardTentacleInstruction phase. " + instruction.phase);
    }
  }

  private void inchTowardPhase0(InchTowardTentacleInstruction instruction) {
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
      rotateSegmentsBy(instruction.segmentIndex, segments.size(), -segmentA.fixedRotationDirection * angleDelta);
      //segmentA.angle(segmentA.angle() - segmentA.fixedRotationDirection * angleDelta);
      //segmentA.updateEndpoint();

      isCurrSegmentComplete = false;
    }

    if (instruction.segmentIndex < segments.size()) {
      updateSegmentPointsBaseToTip(instruction.segmentIndex, segments.size());
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
        rotateSegmentsBy(instruction.segmentIndex + 1, segments.size(), segmentB.fixedRotationDirection * angleDelta);
        //segmentB.angle(segmentB.angle() + segmentB.fixedRotationDirection * angleDelta);
        //segmentB.updateEndpoint();

        isCurrSegmentComplete = false;
      }

      if (instruction.segmentIndex + 1 < segments.size()) {
        updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());
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
          rotateSegmentsBy(instruction.segmentIndex + 2, segments.size(), segmentC.fixedRotationDirection * angleDelta);
          //segmentC.angle(segmentC.angle() + segmentC.fixedRotationDirection * angleDelta);
          //segmentC.updateEndpoint();

          isCurrSegmentComplete = false;
        }

        if (instruction.segmentIndex + 2 < segments.size()) {
          updateSegmentPointsBaseToTip(instruction.segmentIndex + 2, segments.size());
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

  private void inchTowardPhase1(InchTowardTentacleInstruction instruction) {
    TentacleSegment tipSegment = segments.get(segments.size() - 1);

    // Now the tentacle is in a box shape. Rotate the second segment clockwise
    // and the third segment counter-clockwise until the tip touches the surface.
    TentacleSegment segmentA2 = segments.get(instruction.segmentIndex);
    TentacleSegment segmentB2 = segments.get(instruction.segmentIndex + 1);
    TentacleSegment segmentC2 = segments.get(instruction.segmentIndex + 2);

    float prevRotationB = segmentB2.angle();
    float prevRotationC = segmentC2.angle();

    rotateSegmentsBy(instruction.segmentIndex + 1, segments.size(), segmentB2.fixedRotationDirection * segmentB2.maxAngleDelta);
    rotateSegmentsBy(instruction.segmentIndex + 2, segments.size(), -segmentC2.fixedRotationDirection * segmentC2.maxAngleDelta);
    updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());

    if (detectCollision(tipSegment)) {
      tipSegment.isFixed = true;
      tipSegment.fixedRotationDirection = segmentB2.fixedRotationDirection;

      // Rotate 1° at a time until collision detected.
      float prevAngleB = 0; // TODO: Give this a better name so I know it's the angle before the collision.
      float prevAngleC = 0;
      // TODO: Don't track max angle delta for each segment separately. It leads to situations like this where
      // I need to iterate from 0 to two (potentially) different values of maxAngleDelta. Can add later if need.
      for (float a = 0; a < segmentB2.maxAngleDelta; a += radians(1)) {
        setSegmentsAngle(instruction.segmentIndex + 1, segments.size(), prevRotationB + segmentB2.fixedRotationDirection * a);
        setSegmentsAngle(instruction.segmentIndex + 2, segments.size(), prevRotationC - segmentC2.fixedRotationDirection * a);
        updateSegmentPointsBaseToTip(instruction.segmentIndex + 1, segments.size());
        
        if (detectCollision(tipSegment)) {
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

  private void inchTowardPhase2(InchTowardTentacleInstruction instruction) {
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

    // Rotate 90° away from the surface.
    PVector targetVector = prevSegment.getVector();
    targetVector.normalize();
    targetVector.rotate(-segmentA.fixedRotationDirection * PI/2);
    float angleDelta = min(PVector.angleBetween(segmentA.getVector(), targetVector), segmentA.maxAngleDelta);
    if (angleDelta > angleError) {
      segmentA.angle(segmentA.angle() - segmentA.fixedRotationDirection * angleDelta);
      segmentA.updateEndpoint();

      isCurrSegmentComplete = false;

      int firstFixedSegmentIndex = getFirstFixedSegmentIndex(instruction.segmentIndex + 1);
      TentacleSegment firstFixedSegment = segments.get(firstFixedSegmentIndex);
      PVector firstFixedSegmentEndpoint = firstFixedSegment.endpoint();
      simpleIk(instruction.segmentIndex + 1, firstFixedSegmentIndex);
      firstFixedSegment.endpoint(firstFixedSegmentEndpoint);
      updateSegmentPointsTipToBase(firstFixedSegmentIndex, instruction.segmentIndex);
    }

    if (isCurrSegmentComplete) {
      instruction.segmentIndex--;
      if (instruction.segmentIndex <= 0) {
        instruction.isComplete = true;
      }
    }
  }

  private void tryToTriggerContactInstruction(TentacleInstruction originalInstruction) {
    // When recovery instruction is more than halfway through, begin the contact instruction.
    if (originalInstruction.contactTargetDirection != null && originalInstruction.segmentIndex > segments.size() / 2) {
      TentacleInstruction instruction = new TentacleInstruction();
      instruction.targetDirection = originalInstruction.contactTargetDirection.copy();
      instruction.targetDirection.normalize();
      instructions.add(instruction);
    }
  }

  private void cancelOlderInstructions(int instructionIndex, int segmentIndex) {
    for (int i = 0; i < instructionIndex; i++) {
      TentacleInstruction instruction = instructions.get(i);
      if (instruction.segmentIndex <= segmentIndex) {
        instruction.isComplete = true;
      }
    }
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
      segment.isFixed = true;
      segment.fixedRotationDirection = angleSign;

      // Rotate 1° at a time until collision detected.
      float prevAngle = 0; // TODO: Give this a better name so I know it's the angle before the collision.
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
    // TODO: What's a good way to structure the code for collision detection?
    return position.y + segment.endpointY() > surfaceY;
  }

  /**
   * Rotate all the specified segments to the given angle.
   */
  // Not including the segment at endIndex.
  private void setSegmentsAngle(int startIndex, int endIndex, float v) {
    assert(startIndex >= 0);
    assert(endIndex <= segments.size());
    assert(startIndex < endIndex);

    for (int i = startIndex; i < endIndex; i++) {
      TentacleSegment segment = segments.get(i);
      segment.angle(v);
    }
  }

  /**
   * Rotate all the specified segments by the given amount.
   */
  // Not including the segment at endIndex.
  private void rotateSegmentsBy(int startIndex, int endIndex, float v) {
    assert(startIndex >= 0);
    assert(endIndex <= segments.size());
    assert(startIndex < endIndex);

    for (int i = startIndex; i < endIndex; i++) {
      TentacleSegment segment = segments.get(i);
      segment.angle(segment.angle() + v);
    }
  }

  /**
   * Starting at the base and working toward the tip, update each
   * segment's pivot to match the previous segment's endpoint.
   */
  private void updateSegmentPointsBaseToTip() {
    updateSegmentPointsBaseToTip(0, segments.size());
  }

  // Not including the segment at endIndex.
  private void updateSegmentPointsBaseToTip(int startIndex, int endIndex) {
    assert(startIndex >= 0);
    assert(endIndex <= segments.size());
    assert(startIndex < endIndex);

    for (int i = startIndex; i < endIndex; i++) {
      TentacleSegment segment = segments.get(i);
      if (i > 0) {
        // `prevSegment` is the adjacent segment closer to the base.
        TentacleSegment prevSegment = segments.get(i - 1);
        segment.pivot(prevSegment.endpoint());
      } else {
        // The first segment's pivot is set to the tentacle origin.
        segment.pivot(new PVector());
      }
      segment.updateEndpoint();
    }
  }

  /**
   * Starting at the tip and working toward the base, update each
   * segment's endpoint to match the previous segment's pivot.
   */
  private void updateSegmentPointsTipToBase() {
    // Doesn't update the segment at the tip because it has nothing to update to.
    updateSegmentPointsTipToBase(segments.size() - 1, 0);
  }

  // Not including the segment at startIndex.
  private void updateSegmentPointsTipToBase(int startIndex, int endIndex) {
    // Never update the segment at the tip because it has nothing to update to.
    assert(startIndex < segments.size());
    assert(endIndex >= 0);
    assert(startIndex > endIndex);

    for (int i = startIndex - 1; i >= endIndex; i--) {
      TentacleSegment segment = segments.get(i);
      if (i < segments.size() - 1) {
        // `prevSegment` is the adjacent segment closer to the tip.
        TentacleSegment prevSegment = segments.get(i + 1);
        segment.endpoint(prevSegment.pivot());
      }
      segment.updatePivot();
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

  private int getRotationSign(PVector sourceVector, PVector targetVector) {
    if (sourceVector.y * targetVector.x > sourceVector.x * targetVector.y) {
      return RotationDirection.COUNTERCLOCKWISE;
    } else {
      return RotationDirection.CLOCKWISE;
    }
  }
}
