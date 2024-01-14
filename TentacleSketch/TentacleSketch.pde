import java.util.List;


final float baseSegmentLength = 60;
final float tipSegmentLength = 10;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

List<TentacleSegment> segments = new ArrayList<TentacleSegment>();

FileNamer folderNamer;
FileNamer fileNamer;

// Visual debugging.
int currSegmentIndex;

void setup() {
  size(640, 640, P2D);
  background(255);
  
  tentacleX = width/2;
  tentacleY = height/2;
  
  folderNamer = new FileNamer("screenies/build", "/");
  fileNamer = new FileNamer(folderNamer.next() + "frame", "gif");
  
  reset();
}

void reset() {
  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  segments.clear();
  initSegments();
}
  
void initSegments() {
  float baseAngle = radians(-90);
  PVector currPos = new PVector();
  
  for (int i = 0;  i < 8; i++) {
    float segmentLength = map(i, 0, 8, baseSegmentLength, tipSegmentLength);
    TentacleSegment segment = new TentacleSegment(
      segmentLength,
      baseAngle + radians(30) * i,
      currPos.x, currPos.y,
      radians(30));
    segments.add(segment);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  }
  updateTentacleSegments();
  
  currSegmentIndex = segments.size() - 1;
}

void draw() {
  step(1);
  
  background(255);
  
  pushMatrix();
  translate(tentacleX, tentacleY);
  
  stroke(255, 216, 216);
  strokeWeight(2);
  if (mouseReleaseX >= 0) {
    PVector target = new PVector(mouseReleaseX - tentacleX, mouseReleaseY - tentacleY);
    TentacleSegment lastSegment = segments.get(segments.size() - 1);
    for (int i = 0; i < segments.size(); i++) {
      PVector pivot;
      if (i > 0) {
        TentacleSegment prevSegment = segments.get(i - 1);
        pivot = new PVector(prevSegment.x, prevSegment.y);
      } else {
        pivot = new PVector(0, 0);
      }
      
      PVector endpoint = new PVector(lastSegment.x, lastSegment.y);
      
      line(pivot.x, pivot.y, endpoint.x, endpoint.y);
      line(pivot.x, pivot.y, target.x, target.y);
    }
  }
  
  noFill();
  stroke(0);
  strokeWeight(1);
  rectMode(CENTER);
  square(0, 0, 10);
  
  PVector prevPos = new PVector(0, 0);
  PVector currPos = new PVector(0, 0);
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  
    stroke(64);
    if (currSegmentIndex == i) {
      strokeWeight(2);
    } else {
      strokeWeight(1);
    }
    
    line(prevPos.x, prevPos.y, currPos.x, currPos.y);
    circle(currPos.x, currPos.y, 7);
    
    prevPos.set(currPos);
  }
  
  popMatrix();
  
  if (mouseReleaseX >= 0) {
    noFill();
    stroke(0);
    strokeWeight(1);
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
  if (mouseReleaseX >= 0) {
    for (int i = 0; i < count; i++) {
      cyclicCoordinateDescentIK(currSegmentIndex);
      updateTentacleSegments();
      
      currSegmentIndex--;
      if (currSegmentIndex <= 0) {
        currSegmentIndex = segments.size() - 1;
      }
    }
  } 
}

void inverseKinematics() {
  PVector target = new PVector(mouseReleaseX, mouseReleaseY);
  for (int i = segments.size() - 1; i > 0; i--) {
    TentacleSegment segment = segments.get(i);
    TentacleSegment prevSegment = segments.get(i - 1);
    
    segment.angle = atan2(target.y - prevSegment.y - tentacleY, target.x - prevSegment.x - tentacleX);
    target.set(target.x - segment.length * cos(segment.angle), target.y - segment.length * sin(segment.angle));
  }
  
  // Special case for first segment.
  TentacleSegment segment = segments.get(0);
  segment.angle = atan2(target.y - tentacleY, target.x - tentacleX);
}

void inverseKinematics(int segmentIndex) {
  PVector target = new PVector(mouseReleaseX, mouseReleaseY);
  TentacleSegment segment = segments.get(segmentIndex);
  
  PVector pivot;
  if (segmentIndex > 0) {
    TentacleSegment prevSegment = segments.get(segmentIndex - 1);
    pivot = new PVector(prevSegment.x, prevSegment.y);
  } else {
    pivot = new PVector(0, 0);
  }
  
  segment.angle = atan2(target.y - pivot.y - tentacleY, target.x - pivot.x - tentacleX);
  target.set(target.x - segment.length * cos(segment.angle), target.y - segment.length * sin(segment.angle));
}

void cyclicCoordinateDescentIK() {
  PVector target = new PVector(mouseReleaseX - tentacleX, mouseReleaseY - tentacleY);
  TentacleSegment lastSegment = segments.get(segments.size() - 1);
    
  for (int i = segments.size() - 1; i >= 0; i--) {
    TentacleSegment segment = segments.get(i);
    
    PVector pivot;
    if (i > 0) {
      TentacleSegment prevSegment = segments.get(i - 1);
      pivot = new PVector(prevSegment.x, prevSegment.y);
    } else {
      pivot = new PVector(0, 0);
    }
    
    PVector endpoint = new PVector(lastSegment.x, lastSegment.y);
    
    PVector pivotToEndpoint = PVector.sub(endpoint, pivot);
    PVector pivotToTarget = PVector.sub(target, pivot);
    
    float a = PVector.angleBetween(pivotToEndpoint, pivotToTarget);
    
    float sign = 0;
    if (pivotToEndpoint.y * pivotToTarget.x > pivotToEndpoint.x * pivotToTarget.y) {
      sign = -1;
    } else {
      sign = 1;
    }
    segment.angle += sign * a;
    
    // TODO: Optimize by only updating segments after this one.
    updateTentacleSegments();
  }
}

void cyclicCoordinateDescentIK(int segmentIndex) {
  PVector target = new PVector(mouseReleaseX - tentacleX, mouseReleaseY - tentacleY);
  TentacleSegment lastSegment = segments.get(segments.size() - 1);
    
  TentacleSegment segment = segments.get(segmentIndex);
  
  PVector prevSegmentVector;
  PVector pivot;
  if (segmentIndex > 0) {
    TentacleSegment prevSegment = segments.get(segmentIndex - 1);
    prevSegmentVector = new PVector(prevSegment.length * cos(prevSegment.angle), prevSegment.length * sin(prevSegment.angle));
    pivot = new PVector(prevSegment.x, prevSegment.y);
  } else {
    pivot = new PVector(0, 0);
    prevSegmentVector = new PVector(0, baseSegmentLength);
  }
  
  PVector endpoint = new PVector(lastSegment.x, lastSegment.y);
  
  PVector pivotToEndpoint = PVector.sub(endpoint, pivot);
  PVector pivotToTarget = PVector.sub(target, pivot);
  
  float angleDelta = PVector.angleBetween(pivotToEndpoint, pivotToTarget);
  
  float sign = 0;
  if (pivotToEndpoint.y * pivotToTarget.x > pivotToEndpoint.x * pivotToTarget.y) {
    sign = -1;
  } else {
    sign = 1;
  }
  
  float candidateAngle = segment.angle + sign * angleDelta;
  PVector candidate = new PVector(segment.length * cos(candidateAngle), segment.length * sin(candidateAngle));
  if (PVector.angleBetween(candidate, prevSegmentVector) < segment.maxAngleDelta) {
    segment.angle = candidateAngle;
  } else {
    // TODO: Optimize.
    PVector constrainedA = prevSegmentVector.copy();
    constrainedA.rotate(segment.maxAngleDelta);
    PVector constrainedB = prevSegmentVector.copy();
    constrainedB.rotate(-segment.maxAngleDelta);
    if (PVector.angleBetween(candidate, constrainedA) < PVector.angleBetween(candidate, constrainedB)) {
      println("prev: " + round(degrees(prevSegmentVector.heading()))
        + "\tcurr: " + round(degrees(segment.angle))
        + "\tcandidate: " + round(degrees(candidateAngle))
        + "\t(A): " + round(degrees(constrainedA.heading())) + "\tb: " + round(degrees(constrainedB.heading())));
      segment.angle = constrainedA.heading();
    } else {
      println("prev: " + round(degrees(prevSegmentVector.heading()))
        + "\tcurr: " + round(degrees(segment.angle))
        + "\tcandidate: " + round(degrees(candidateAngle))
        + "\ta: " + round(degrees(constrainedA.heading())) + "\t(B): " + round(degrees(constrainedB.heading())));
      segment.angle = constrainedB.heading();
    }
  }
  updateTentacleSegments();
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
}
