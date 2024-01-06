import java.util.List;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

List<TentacleSegment> segments = new ArrayList<TentacleSegment>();

void setup() {
  size(640, 640, P2D);
  background(255);
  
  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  tentacleX = width/2;
  tentacleY = height/2;
  
  initSegments();
}
  
void initSegments() {
  float baseAngle = radians(-90);
  float segmentLength = 30;
  PVector currPos = new PVector();
  
  for (int i = 0;  i < 8; i++) {
    TentacleSegment segment = new TentacleSegment(segmentLength, baseAngle, currPos.x, currPos.y);
    segments.add(segment);
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
  }
  updateTentacleSegments();
}

void draw() {
  background(255);
  
  noFill();
  stroke(0);
  strokeWeight(1);
  rectMode(CENTER);
  square(tentacleX, tentacleY, 10);
  
  PVector prevPos = new PVector(tentacleX, tentacleY);
  PVector currPos = new PVector(tentacleX, tentacleY);
  for (TentacleSegment segment : segments) {
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    
    line(prevPos.x, prevPos.y, currPos.x, currPos.y);
    circle(currPos.x, currPos.y, 7);
    circle(tentacleX + segment.x, tentacleY + segment.y, 4);
    
    prevPos.set(currPos);
  }
  
  if (mouseReleaseX >= 0) {
    noFill();
    stroke(0);
    strokeWeight(1);
    circle(mouseReleaseX, mouseReleaseY, 5);
  }
}

void updateTentacleSegments() {
  PVector currPos = new PVector();
  for (TentacleSegment segment : segments) {
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    segment.x = currPos.x;
    segment.y = currPos.y;
    println(segment.x, segment.y);
  } 
}

void step() {
  if (mouseReleaseX >= 0) {
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
    
    updateTentacleSegments();
  } 
}

void keyReleased() {
  switch (key) {
    case ' ':
      step();
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
