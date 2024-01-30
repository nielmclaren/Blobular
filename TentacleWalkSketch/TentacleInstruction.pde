
class TentacleInstruction {
  public int rotationDirection;
  public PVector targetDirection;
  public PVector contactTargetDirection;
  public int segmentIndex;
  public boolean isComplete;
  
  TentacleInstruction() {
    rotationDirection = 0;
    targetDirection = null;
    contactTargetDirection = null;
    segmentIndex = 0;
    isComplete = false;
  }
}
