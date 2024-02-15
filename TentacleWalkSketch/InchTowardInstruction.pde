
class InchTowardInstruction extends TentacleInstruction {
  public int phase;
  public PVector direction;
  public int segmentIndex;

  public InchTowardInstruction() {
    phase = 0;
    direction = null;
    segmentIndex = 0;
  }
}