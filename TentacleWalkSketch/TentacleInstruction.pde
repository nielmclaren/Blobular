
class TentacleInstruction {
  public int rotationDirection;
  public PVector targetDirection;
  public int segmentIndex;
  public boolean isComplete;
  
  TentacleInstruction() {
    rotationDirection = 0;
    targetDirection = null;
    segmentIndex = 0;
    isComplete = false;
  }
}
