import java.util.List;

Tentacle tentacle;

float mouseReleaseX;
float mouseReleaseY;

float tentacleX;
float tentacleY;

PVector currTargetDirection;
float surfaceY;

FileNamer folderNamer;
FileNamer fileNamer;

void setup() {
  size(640, 640, P2D);
  background(255);

  tentacle = new Tentacle();
  
  tentacleX = width/2;
  tentacleY = height/2;
  
  currTargetDirection = null;
  surfaceY = height * 0.75;
  
  folderNamer = new FileNamer("screenies/build", "/");
  fileNamer = new FileNamer(folderNamer.next() + "frame", "gif");
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
  List<TentacleSegment> segments = tentacle.segments();
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    currPos.add(segment.getVector());
  
    stroke(Palette.base[1]);
    strokeWeight(2);
    
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
    case 'a':
      tentacleX -= 10;
      break;
    case 'd':
      tentacleX += 10;
      break;
    case ' ':
      tentacle.step(1);
      break;
    case 't':
      save(fileNamer.next());
      break;
  }
}

void mouseReleased() {
  mouseReleaseX = mouseX;
  mouseReleaseY = mouseY;

  tentacle.pointTo(new PVector(mouseX - tentacleX, mouseY - tentacleY));
}

int getRotationSign(PVector sourceVector, PVector targetVector) {
  if (sourceVector.y * targetVector.x > sourceVector.x * targetVector.y) {
    return RotationDirection.COUNTERCLOCKWISE;
  } else {
    return RotationDirection.CLOCKWISE;
  }
}
