import java.util.List;

final float baseSegmentLength = 60;
final float tipSegmentLength = 10;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

List<TentacleSegment> segments = new ArrayList<TentacleSegment>();
List<TentacleInstruction> instructions = new ArrayList<TentacleInstruction>();

PVector currTargetDirection;
float surfaceY;
int phase;
boolean collisionDetected;

FileNamer folderNamer;
FileNamer fileNamer;

void setup() {
  size(640, 640, P2D);
  background(255);
  
  tentacleX = width/2;
  tentacleY = height/2;
  
  segments = new ArrayList<TentacleSegment>();
  instructions = new ArrayList<TentacleInstruction>();
  
  currTargetDirection = null;
  surfaceY = height * 0.75;
  phase = 0;
  collisionDetected = false;
  
  folderNamer = new FileNamer("screenies/build", "/");
  fileNamer = new FileNamer(folderNamer.next() + "frame", "gif");
  
  reset();
}

void reset() {
  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  segments.clear();
  instructions.clear();
  initSegments();
}
  
void initSegments() {
  float baseAngle = radians(90);
  PVector currPos = new PVector();
  int numSegments = 8;
  
  for (int i = 0;  i < numSegments; i++) {
    float segmentLength = map(i, 0, numSegments, baseSegmentLength, tipSegmentLength);
    TentacleSegment segment = new TentacleSegment(
      segmentLength,
      baseAngle + radians(30) * i,
      currPos.x, currPos.y,
      radians(20));
    segments.add(segment);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  }
  updateTentacleSegments();
}

void draw() {
  step(segments.size());
  
  background(Palette.light[2]);
  
  noStroke();
  fill(Palette.light[4]);
  rectMode(CORNERS);
  rect(0, surfaceY, width, height);
  stroke(Palette.base[3]);
  line(0, surfaceY, width, surfaceY);
  
  pushMatrix();
  translate(tentacleX, tentacleY);
  
  noFill();
  stroke(Palette.base[1]);
  strokeWeight(2);
  rectMode(CENTER);
  square(0, 0, 10);

  TentacleInstruction instruction = instructions.size() > 0 ? instructions.get(0) : null;
  
  PVector prevPos = new PVector(0, 0);
  PVector currPos = new PVector(0, 0);
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  
    if (instruction != null && instruction.segmentIndex == i) {
      stroke(Palette.base[0]);
      strokeWeight(2);
    } else {
      stroke(Palette.base[1]);
      strokeWeight(2);
    }
    
    line(prevPos.x, prevPos.y, currPos.x, currPos.y);
    circle(currPos.x, currPos.y, 7);
    
    prevPos.set(currPos);
  }
  
  popMatrix();
  
  if (mouseReleaseX >= 0) {
    noFill();
    stroke(Palette.base[3]);
    strokeWeight(2);
    circle(mouseReleaseX, mouseReleaseY, 5);
  }
}

// Update each segment's endpoint based on their lengths and angles.
void updateTentacleSegments() {
  PVector currPos = new PVector();
  for (TentacleSegment segment : segments) {
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    segment.x = currPos.x;
    segment.y = currPos.y;
  } 
}

void step(int count) {
  if (instructions.size() <= 0) {
    if (phase == 0) {
      // Need a little extra room for the tentacle segments to get through.
      float clearance = 10;

      float tentacleLength = getTentacleLength();
      float deltaY = surfaceY - tentacleY - clearance;
      float deltaX = sqrt(tentacleLength * tentacleLength - deltaY * deltaY);

      TentacleInstruction instruction = new TentacleInstruction();
      currTargetDirection = new PVector(deltaX, deltaY);
      instruction.targetDirection = currTargetDirection;
      instructions.add(instruction);

      phase++;
    } else if (phase == 1) {
      TentacleSegment lastSegment = segments.get(segments.size() - 1);
      if (currTargetDirection.x < 0 && !collisionDetected) {
        // Full step is complete.
        phase = 0;
      } else {
        TentacleInstruction instruction = new TentacleInstruction();
        currTargetDirection.rotate(radians(10));
        instruction.targetDirection = currTargetDirection;
        instructions.add(instruction);
      }
    }
  }
  
  collisionDetected = false;
  for (TentacleInstruction instruction : instructions) {
    TentacleSegment segment = segments.get(instruction.segmentIndex);
    PVector pivot = getPivot(instruction.segmentIndex);
    PVector segmentVector = segment.getVector();
    
    float prevRotation = segment.angle;
    float angleError = radians(0.5);
    float angleDelta = min(PVector.angleBetween(segmentVector, instruction.targetDirection), segment.maxAngleDelta);
    
    int angleSign;
    if (instruction.rotationDirection == 0) {
      angleSign = getRotationSign(segmentVector, instruction.targetDirection);
    } else {
      angleSign = instruction.rotationDirection;
    }
    
    segment.angle += angleSign * angleDelta;
    segment.updateEndpoint(pivot);
    
    boolean collided = handleCollisions(segment, pivot, prevRotation, angleSign, angleDelta);
    if (collided) {
      collisionDetected = true;
      instruction.rotationDirection = angleSign;
    }
    
    dragRemainingSegments(instruction.segmentIndex + 1);
    updateTentacleSegments();
    
    // If this segment is in position then move onto next segment for the next iteration.
    angleDelta = min(PVector.angleBetween(segment.getVector(), instruction.targetDirection), segment.maxAngleDelta);
    if (collided || angleDelta <= angleError) {
      instruction.segmentIndex++;
      if (instruction.segmentIndex >= segments.size()) {
        instruction.isComplete = true;
      }
    }
  } 

  instructions.removeIf(instruction -> instruction.isComplete);
}

float getTentacleLength() {
  float total = 0;
  for (TentacleSegment segment : segments) {
    total += segment.length;
  }
  return total;
}

boolean handleCollisions(TentacleSegment segment, PVector pivot, float prevRotation, int angleSign, float angleDelta) {
  // FIXME: Assumes segment was not originally in a collided state.
  if (detectCollision(segment)) {
    // Rotate 1° at a time until collision detected.
    float prevAngle = 0;
    for (float a = 0; a < angleDelta; a += radians(1)) {
      segment.angle = prevRotation + angleSign * a;
      segment.updateEndpoint(pivot);
      
      if (detectCollision(segment)) {
        break;
      }
      
      prevAngle = segment.angle;
    }
    
    segment.angle = prevAngle;
    segment.updateEndpoint(pivot);
    
    return true;
  }
  return false;
}

boolean detectCollision() {
  for (TentacleSegment segment : segments) {
    if (detectCollision(segment)) {
      return true;
    }
  }
  return false;
}

boolean detectCollision(TentacleSegment segment) {
  return tentacleY + segment.y > surfaceY;
}

void dragRemainingSegments(int startSegmentIndex) {
  for (int i = startSegmentIndex; i < segments.size(); i++) {
    PVector pivot;
    if (i > 0) {
      TentacleSegment prevSegment = segments.get(i - 1);
      pivot = new PVector(prevSegment.x, prevSegment.y);
    } else {
      pivot = new PVector(0, 0);
    }
  
    TentacleSegment segment = segments.get(i);
    PVector endpoint = new PVector(segment.x, segment.y);
    PVector pivotToEndpoint = PVector.sub(endpoint, pivot);
    
    segment.angle = pivotToEndpoint.heading();
    segment.setEndpoint(PVector.add(pivot, segment.getVector()));

    handleDragCollisions(segment, pivot);
  }
}

void handleDragCollisions(TentacleSegment segment, PVector pivot) {
  if (detectCollision(segment)) {
    collisionDetected = true;

    float prevAngle = segment.angle;

    // Try rotating in both directions to find the minimum amount of rotation necessary.
    for (float a = 0; a < PI; a += radians(1)) {
      segment.angle = prevAngle + a;
      segment.updateEndpoint(pivot);

      if (!detectCollision(segment)) return;

      segment.angle = prevAngle - a;
      segment.updateEndpoint(pivot);

      if (!detectCollision(segment)) return;
    }

    // FIXME: Can I throw an exception here instead?
    println("No way to not collide!");
  }
}

PVector getPivot(int segmentIndex) {
    if (segmentIndex > 0) {
      TentacleSegment prevSegment = segments.get(segmentIndex - 1);
      return new PVector(prevSegment.x, prevSegment.y);
    } else {
      return new PVector(0, 0);
    }
}

float normalizeAngle(float v) {
  while (v < 0) {
    v += TAU;
  }
  while (v > TAU) {
    v -= TAU;
  }
  return v;
}

void keyReleased() {
  switch (key) {
    case ' ':
      step(1);
      break;
    case 'r':
      reset();
      break;
    case 't':
      save(fileNamer.next());
      break;
  }
}

void mouseReleased() {
  mouseReleaseX = mouseX;
  mouseReleaseY = mouseY;
  
  instructions.clear();
  TentacleInstruction instruction = new TentacleInstruction();
  instruction.targetDirection = new PVector(mouseX - tentacleX, mouseY - tentacleY);
  instructions.add(instruction);
}

int getRotationSign(PVector sourceVector, PVector targetVector) {
  if (sourceVector.y * targetVector.x > sourceVector.x * targetVector.y) {
    return RotationDirection.COUNTERCLOCKWISE;
  } else {
    return RotationDirection.CLOCKWISE;
  }
}
