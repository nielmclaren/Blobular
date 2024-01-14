import java.util.List;


final float baseSegmentLength = 60;
final float tipSegmentLength = 10;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

List<TentacleSegment> segments = new ArrayList<TentacleSegment>();

float surfaceY;

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
  
  surfaceY = height * 0.75;
  
  reset();
}

void reset() {
  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  segments.clear();
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
  
  currSegmentIndex = segments.size() - 1;
}

void draw() {
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
  
  PVector prevPos = new PVector(0, 0);
  PVector currPos = new PVector(0, 0);
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  
    if (currSegmentIndex == i) {
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
  if (mouseReleaseX >= 0) {
    TentacleSegment segment = segments.get(currSegmentIndex);
    PVector pivot = getPivot(currSegmentIndex);
    PVector segmentVector = segment.getVector();
    
    // Only using target to indicate direction so don't need to subtract the pivot point.
    PVector target = new PVector(mouseReleaseX - tentacleX, mouseReleaseY - tentacleY);
    
    float angleError = radians(0.5);
    float angleDelta = min(PVector.angleBetween(segmentVector, target), segment.maxAngleDelta);
    
    int angleSign = getRotationSign(segmentVector, target);
    
    segment.angle += angleSign * angleDelta;
    segment.setEndpoint(PVector.add(pivot, segment.getVector()));
    
    dragRemainingSegments(currSegmentIndex + 1);
    updateTentacleSegments();
    
    // If this segment is in position move onto next segment for the next iteration.
    angleDelta = min(PVector.angleBetween(segment.getVector(), target), segment.maxAngleDelta);
    if (angleDelta <= angleError) {
      currSegmentIndex++;
      if (currSegmentIndex >= segments.size()) {
        currSegmentIndex = 0;
      }
    }
  } 
}

void dragRemainingSegments(int startSegmentIndex) {
  for (int i = startSegmentIndex; i < segments.size(); i++) {
    PVector target;
    if (i > 0) {
      TentacleSegment prevSegment = segments.get(i - 1);
      target = new PVector(prevSegment.x, prevSegment.y);
    } else {
      target = new PVector(0, 0);
    }
  
    TentacleSegment segment = segments.get(i);
    PVector endpoint = new PVector(segment.x, segment.y);
    PVector targetToEndpoint = PVector.sub(endpoint, target);
    
    segment.angle = targetToEndpoint.heading();
    segment.setEndpoint(PVector.add(target, segment.getVector()));
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
  currSegmentIndex = 0;
}

int getRotationSign(PVector sourceVector, PVector targetVector) {
  if (sourceVector.y * targetVector.x > sourceVector.x * targetVector.y) {
    return -1;
  } else {
    return 1;
  }
}
