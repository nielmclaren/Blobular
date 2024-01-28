import java.util.List;

Tentacle tentacle;

float mouseReleaseX;
float mouseReleaseY;

final float playerSpeed = 3;
PVector position;
PVector velocity;

PVector currTargetDirection;
float surfaceY;

PlayerInput playerInput;

FileNamer folderNamer;
FileNamer fileNamer;

void setup() {
  size(640, 640, P2D);
  background(255);

  tentacle = new Tentacle();

  mouseReleaseX = -1;
  mouseReleaseY = -1;
  
  position = new PVector(width/3, height/2); 
  velocity = new PVector();

  currTargetDirection = null;
  surfaceY = height * 0.75;

  playerInput = new PlayerInput(this);
  
  folderNamer = new FileNamer("screenies/build", "/");
  fileNamer = new FileNamer(folderNamer.next() + "frame", "gif");
}

void draw() {
  handlePlayerMovement();

  background(Palette.light[2]);

  drawGround();
  
  pushMatrix();
  translate(position.x, position.y);
  
  noFill();
  stroke(Palette.base[1]);
  strokeWeight(2);
  rectMode(CENTER);
  square(0, 0, 10);

  drawSegments();

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

void handlePlayerMovement() {
  playerInput.loadInputDirection(velocity);
  velocity.mult(playerSpeed);

  tentacle.move(velocity.x, velocity.y);
  position.add(velocity);
}

void drawGround() {
  pushStyle();
  
  noStroke();
  fill(Palette.light[4]);
  rectMode(CORNERS);
  rect(0, surfaceY, width, height);
  stroke(Palette.base[3]);
  line(0, surfaceY, width, surfaceY);

  popStyle();
}

void drawSegments() {
  pushStyle();

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

  popStyle();
}

void keyPressed() {
  playerInput.keyPressed(key);
}

void keyReleased() {
  playerInput.keyReleased(key);
  switch (key) {
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

  tentacle.pointTo(new PVector(mouseX - position.x, mouseY - position.y));
}