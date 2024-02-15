
// The tentacle origin is at 0, 0. The tentacle base is the position of the first
// segment's pivot, which may or may not match the tentacle origin.
public class Tentacle {
  protected List<TentacleSegment> segments;
  protected List<TentacleInstruction> instructions;

  protected InchToward inchToward;

  public Tentacle() {
    segments = new ArrayList<TentacleSegment>();
    instructions = new ArrayList<TentacleInstruction>();

    inchToward = new InchToward(this);

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
        radians(2));

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
    PointAtInstruction instruction = new PointAtInstruction(this);
    instruction.targetDirection = direction.copy();
    instruction.targetDirection.normalize();
    instructions.add(instruction);
  }

  public void recoveryAndContact(PVector recoveryDirection, PVector contactDirection) {
    PointAtInstruction instruction = new PointAtInstruction(this);
    instruction.targetDirection = recoveryDirection.copy();
    instruction.targetDirection.normalize();
    instruction.contactTargetDirection = contactDirection.copy();
    instruction.contactTargetDirection.normalize();
    instructions.add(instruction);
  }

  public void inchToward(PVector direction) {
    InchTowardInstruction instruction = new InchTowardInstruction();
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

  protected void setSegmentsIsFixed(int startIndex, int endIndex, boolean v, int rotationDirection) {
    for (int i = startIndex; i < endIndex; i++) {
      TentacleSegment segment = segments.get(i);
      segment.isFixed = v;
      segment.fixedRotationDirection = rotationDirection;
    }
  }

  protected int getFirstFixedSegmentIndex() {
    return getFirstFixedSegmentIndex(0);
  }

  protected int getFirstFixedSegmentIndex(int startIndex) {
    for (int i = startIndex; i < segments.size(); i++) {
      TentacleSegment segment = segments.get(i);
      if (segment.isFixed) {
        return i;
      }
    }
    return -1;
  }

  // Includes the length of both the specified segments.
  protected float getLengthBetweenIncl(int startSegmentIndex, int endSegmentIndex) {
    float total = 0;
    for (int i = startSegmentIndex; i <= endSegmentIndex; i++) {
      TentacleSegment segment = segments.get(i);
      total += segment.length();
    }
    return total;
  }

  // Rotate segments to move the segment at startIndex to the previous segment's
  // endpoint or to the tentacle origin.
  // Includes startIndex and endIndex.
  protected void simpleIk(int startIndex, int endIndex) {
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

      // Move the current segment so that its pivot is at the previous segment's endpoint.
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
        // It is possible to encounter completed instructions here because of `cancelOlderPointAtInstructions()`.
        continue;
      }

      evaluateInstructionAt(i);
    }

    instructions.removeIf(instruction -> instruction.isComplete);
  }

  private void evaluateInstructionAt(int instructionIndex) {
    TentacleInstruction instruction = instructions.get(instructionIndex);
    if (instruction instanceof InchTowardInstruction) {
      inchToward.step((InchTowardInstruction) instruction);
      return;
    }

    if (instruction instanceof PointAtInstruction) {
      ((PointAtInstruction) instruction).step(instructionIndex);
    }
  }

  protected void tryToTriggerContactInstruction(PointAtInstruction originalInstruction) {
    // When recovery instruction is more than halfway through, begin the contact instruction.
    if (originalInstruction.contactTargetDirection != null && originalInstruction.segmentIndex > segments.size() / 2) {
      PointAtInstruction instruction = new PointAtInstruction(this);
      instruction.targetDirection = originalInstruction.contactTargetDirection.copy();
      instruction.targetDirection.normalize();
      instructions.add(instruction);
    }
  }

  protected void cancelOlderPointAtInstructions(int instructionIndex, int segmentIndex) {
    for (int i = 0; i < instructionIndex; i++) {
      TentacleInstruction instruction = instructions.get(i);
      if (instruction instanceof PointAtInstruction) {
        if (((PointAtInstruction) instruction).segmentIndex <= segmentIndex) {
          instruction.isComplete = true;
        }
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

  // Protected?
  protected boolean detectCollision() {
    for (TentacleSegment segment : segments) {
      if (detectCollision(segment)) {
        return true;
      }
    }
    return false;
  }

  // Protected?
  protected boolean detectCollision(TentacleSegment segment) {
    // TODO: What's a good way to structure the code for collision detection?
    return position.y + segment.endpointY() > surfaceY;
  }

  // Protected?
  protected boolean detectPivotCollision(TentacleSegment segment) {
    return position.y + segment.pivotY() > surfaceY;
  }

  /**
   * Rotate all the specified segments to the given angle.
   */
  // Not including the segment at endIndex.
  protected void setSegmentsAngle(int startIndex, int endIndex, float v) {
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
  protected void rotateSegmentsBy(int startIndex, int endIndex, float v) {
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
  protected void updateSegmentPointsBaseToTip() {
    updateSegmentPointsBaseToTip(0, segments.size());
  }

  // Not including the segment at endIndex.
  protected void updateSegmentPointsBaseToTip(int startIndex, int endIndex) {
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
  protected void updateSegmentPointsTipToBase() {
    // Doesn't update the segment at the tip because it has nothing to update to.
    updateSegmentPointsTipToBase(segments.size() - 1, 0);
  }

  // Not including the segment at startIndex.
  protected void updateSegmentPointsTipToBase(int startIndex, int endIndex) {
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
  protected void dragRemainingSegments(int startSegmentIndex) {
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
