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
  //tentacle.step();

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

  drawSegments();
  drawDistToFixedSegment();

  popMatrix();
  
  if (mouseReleaseX >= 0) {
    noFill();
    stroke(Palette.base[3]);
    strokeWeight(2);
    float offset = 5;
    line(mouseReleaseX - offset, mouseReleaseY - offset, mouseReleaseX + offset, mouseReleaseY + offset);
    line(mouseReleaseX + offset, mouseReleaseY - offset, mouseReleaseX - offset, mouseReleaseY + offset);
  }
}

void drawSegments() {
  // Draw the line first.
  List<TentacleSegment> segments = tentacle.segments();
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
  
    strokeWeight(2);
    if (segment.isFixed) {
      stroke(Palette.base[3]);
    } else {
      stroke(Palette.base[1]);
    }

    line(segment.pivotX(), segment.pivotY(), segment.endpointX(), segment.endpointY());
  }

  // Draw circles over the line.
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
  
    strokeWeight(2);
    if (segment.isFixed) {
      stroke(Palette.base[3]);
      fill(Palette.light[3]);
    } else {
      stroke(Palette.base[1]);
      fill(Palette.light[1]);
    }
    
    circle(segment.endpointX(), segment.endpointY(), 9);
  }

  // Draw labels
  float totalLength = 0;
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    totalLength += segment.length();

    pushMatrix();
    translate(segment.endpointX(), segment.endpointY());
    rotate(radians(45));

    pushStyle();
    fill(64);
    textSize(12);

    text("" + round(totalLength), 10, 4);

    popStyle();
    popMatrix();
  }
}

void drawDistToFixedSegment() {
  List<TentacleSegment> segments = tentacle.segments();
  for (int i = 0; i < segments.size(); i++) {
    TentacleSegment segment = segments.get(i);
    if (segment.isFixed) {
      pushStyle();
      strokeWeight(1);
      stroke(128);
      line(0, 0, segment.endpointX(), segment.endpointY());
      fill(64);
      textSize(12);
      textAlign(CENTER);
      PVector p = segment.endpoint();
      p.mult(0.5);
      text("" + round(segment.endpoint().mag()), p.x, p.y);
      popStyle();
      break;
    }
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
      tentacle.shiftBase(-10, 0);
      tentacleX -= 10;
      break;
    case 'd':
      tentacle.shiftBase(10, 0);
      tentacleX += 10;
      break;
    case 'w':
      tentacle.shiftBase(0, -10);
      tentacleY -= 10;
      break;
    case 's':
      tentacle.shiftBase(0, 10);
      tentacleY += 10;
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
