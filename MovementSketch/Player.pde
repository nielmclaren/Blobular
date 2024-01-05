
import java.util.List;

class Player {
  private final float maxVelocity = 5;
  private final float accelerationRate = 0.1;
  private final float steerRate = radians(20);
  private final float steerSpeed = 0.4;
  
  private PVector position;
  private PVector velocity;
  
  // Keep these in sync with position.
  public float x;
  public float y;
  
  // Keep this in sync with velocity.
  public PVector direction;
  
  private boolean isRunning;
  
  // TODO: Protect this member.
  public List<Tentacle> tentacles;
  
  Player(float argX, float argY) {
    position = new PVector(argX, argY);
    velocity = new PVector();
    
    x = position.x;
    y = position.y;
    direction = new PVector(1, 0);
    
    isRunning = false;
    
    tentacles = new ArrayList<Tentacle>();
    tentacles.add(new Tentacle(PVector.mult(PVector.fromAngle(radians(90)), 15), radians(90)));
  }
  
  public void steerToward(PVector targetDirection) {
    targetDirection.setMag(maxVelocity + (isRunning ? maxVelocity : 0));
    velocity.lerp(targetDirection, steerSpeed);
    //polarInterpolation(velocity, targetDirection);
    position.add(velocity);
    
    x = position.x;
    y = position.y;
    
    direction.set(velocity);
    direction.normalize();
  }
  
  public void isRunning(boolean v) {
    isRunning = v;
  }
  
  private void polarInterpolation(PVector v, PVector u) {
    float m = v.mag();
    float r = atan2(v.y, v.x); // atan2() returns a value in (-PI, PI]
    float targetM = u.mag();
    float targetR = targetM > 0 ? atan2(u.y, u.x) : r; // atan2() returns a value in (-PI, PI]
    
    float nextM = m + (targetM - m) * accelerationRate;
    float deltaR = targetR - r;
    
    // TODO: Randomize direction of turn when deltaR == 180°
    // Actually that only happens on init, just add jitter to initial player orientation instead.
    
    if (deltaR > PI) deltaR = deltaR - TAU;
    if (deltaR < -PI) deltaR = TAU + deltaR;
    
    //float nextR = r + deltaR * steerSpeed;
    float nextR;
    if (abs(deltaR) < steerRate) {
      nextR = targetR;
    } else {
      nextR = r + (deltaR > 0 ? steerRate : -steerRate);
    }
      
    v.set(cos(nextR) * nextM, sin(nextR) * nextM);
  }
}
