import java.util.List;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

int currSegmentIndex;
TentacleSegment newSegment;

List<TentacleSegment> segments = new ArrayList<TentacleSegment>();

List<LineSegment> debugLineSegments = new ArrayList<LineSegment>();

void setup() {
  size(640, 640, P2D);
  background(255);
  
  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  tentacleX = width/2;
  tentacleY = height/2;
  
  currSegmentIndex = -1;
  
  initSegments();
  
  debugLineSegments = new ArrayList<LineSegment>();
}
  
void initSegments() {
  float baseAngle = radians(-90);
  float segmentLength = 30;
  PVector currPos = new PVector();
  
  for (int i = 0;  i < 8; i++) {
    TentacleSegment segment = new TentacleSegment(segmentLength, baseAngle + radians(30) * i, currPos.x, currPos.y);
    segments.add(segment);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  }
  updateTentacleSegments();
  
  newSegment = null;
}

void draw() {
  background(255);
  
  pushMatrix();
  translate(tentacleX, tentacleY);
  
  println(debugLineSegments.size());
  for (int i = 0; i < debugLineSegments.size(); i++) {
    LineSegment debugLineSegment = debugLineSegments.get(i);
    
    if (floor(i / 2) == currSegmentIndex) {
      stroke(255, 0, 0);
      strokeWeight(2);
    } else {
      stroke(255, 216, 216);
      strokeWeight(2);
    }
    
    line(debugLineSegment.x0, debugLineSegment.y0, debugLineSegment.x1, debugLineSegment.y1);
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
    
    if (currSegmentIndex == i) {
      strokeWeight(1);
      stroke(0);
      fill(0);
    } else {
      strokeWeight(1);
      stroke(64);
      noFill();
    }
    
    line(prevPos.x, prevPos.y, currPos.x, currPos.y);
    circle(currPos.x, currPos.y, 7);
    
    if (currSegmentIndex == i && newSegment != null) {
      strokeWeight(2);
      stroke(0, 0, 255);
      noFill();
      line(prevPos.x, prevPos.y, prevPos.x + newSegment.length * cos(newSegment.angle), prevPos.y + newSegment.length * sin(newSegment.angle));
    }
    
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

void step() {
  if (mouseReleaseX >= 0) {
    if (currSegmentIndex <= 0) {
      currSegmentIndex = segments.size() - 1;
    } else {
      currSegmentIndex--;
    }
    cyclicCoordinateDescentIK();
    updateTentacleSegments();
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

void cyclicCoordinateDescentIK() {
  debugLineSegments.clear();
  
  PVector target = new PVector(mouseReleaseX - tentacleX, mouseReleaseY - tentacleY);
  TentacleSegment lastSegment = segments.get(segments.size() - 1);
    
  //for (int i = segments.size() - 1; i >= 0; i--) {
  for (int i = 0; i < segments.size(); i++) {
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
    
    debugLineSegments.add(new LineSegment(pivot, endpoint));
    debugLineSegments.add(new LineSegment(pivot, target));
    
    float a = PVector.angleBetween(pivotToEndpoint, pivotToTarget);
    //float a = acos(PVector.dot(pivotToEndpoint, pivotToTarget) / pivotToEndpoint.mag() / pivotToTarget.mag());
    //segment.angle += a;
    
    float sign = 0;
    if (pivotToEndpoint.y * pivotToTarget.x > pivotToEndpoint.x * pivotToTarget.y) {
      sign = -1;
    } else {
      sign = 1;
    }
    
    if (i == currSegmentIndex) {
      newSegment = new TentacleSegment(segment.length, segment.angle + sign * a, 100, 100);
    }
    
    // TODO: Optimize by only updating segments after this one.
    updateTentacleSegments();
  }
  
  // Special case for first segment.
  TentacleSegment segment = segments.get(0);
  //segment.angle = atan2(target.y - tentacleY, target.x - tentacleX);
}

void constrainAngles() {
  for (TentacleSegment segment : segments) {
    println(degrees(segment.angle));
  }
  
  /*
  // Constrain the segment's angle to the prevSegment's angle.
  for (int i = segments.size() - 1; i > 0; i--) {
  //for (int i = 1; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    TentacleSegment prevSegment = segments.get(i - 1);
    
    PVector delta = new PVector(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    PVector prevDelta = new PVector(prevSegment.length * cos(prevSegment.angle), prevSegment.length * sin(prevSegment.angle));
    println("delta", abs(degrees(PVector.angleBetween(delta, prevDelta))));
    if (abs(PVector.angleBetween(delta, prevDelta)) > PI/2) {
      if (PVector.angleBetween(delta, prevDelta) <= 0) {
        segment.angle = prevSegment.angle - PI/2;
      } else {
        segment.angle = prevSegment.angle + PI/2;
      }
    }
  }
  /*/
  
  // Constrain the prevSegment's angle to the segment's angle.
  for (int i = segments.size() - 1; i > 0; i--) {
  //for (int i = 1; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    TentacleSegment prevSegment = segments.get(i - 1);
    
    PVector delta = new PVector(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    PVector prevDelta = new PVector(prevSegment.length * cos(prevSegment.angle), prevSegment.length * sin(prevSegment.angle));
    println("delta", abs(degrees(PVector.angleBetween(delta, prevDelta))));
    if (abs(PVector.angleBetween(delta, prevDelta)) > PI/2) {
      if (PVector.angleBetween(delta, prevDelta) <= 0) {
        prevSegment.angle = segment.angle - PI/2;
      } else {
        prevSegment.angle = segment.angle + PI/2;
      }
    }
  }
  //*/
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
      step();
      break;
    case 'c':
      constrainAngles();
      updateTentacleSegments();
      break;
    case 'r':
      saveFrame("frame####.png");
      break;
  }
}

void mouseReleased() {
  mouseReleaseX = mouseX;
  mouseReleaseY = mouseY;
}
