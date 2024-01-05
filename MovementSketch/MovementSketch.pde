import java.awt.event.KeyEvent;

World world;
Player player;
Controller controller;

void setup() {
  size(1024, 1024, P2D);
  background(255);
  
  player = new Player(width * 0.5, height * 0.8 - 15);
  controller = new Controller(player);
}

void draw() {
  controller.step();
  fadeToWhite();
  drawPlayer();
  drawGround();
}

void fadeToWhite() {
  noStroke();
  fill(255, 30);
  rect(0, 0, width, height);
  
  // Required to make it go all the way to white
  loadPixels();
  for (int i = 0; i < pixels.length; i++) {
    if (brightness(pixels[i]) > 240) {
      pixels[i] = color(255);
    }
  }
  updatePixels();
}

void drawPlayer() {
  strokeWeight(2);
  stroke(0);
  drawTentacles(player);
  circle(player.x, player.y, 15);
  line(player.x, player.y, player.x + player.direction.x * 15, player.y + player.direction.y * 15);
}

void drawTentacles(Player player) {
  pushMatrix();
  translate(player.position.x, player.position.y);
  
  for (Tentacle tentacle : player.tentacles) {
    line(0, 0, tentacle.position.x, tentacle.position.y);
    fill(255);
    
    pushMatrix();
    translate(tentacle.position.x, tentacle.position.y);
    
    square(0, 0, 3);
    
    drawTentacleSegments(tentacle);
    popMatrix();
  }
  
  popMatrix();
}

void drawTentacleSegments(Tentacle tentacle) {
  PVector prevPos = new PVector();
  PVector currPos = new PVector();
  for (TentacleSegment segment : tentacle.segments) {
    currPos.add(segment.length * cos(segment.angle), segment.length * sin(segment.angle));
    
    line(prevPos.x, prevPos.y, currPos.x, currPos.y);
    circle(currPos.x, currPos.y, 3);
    prevPos.set(currPos);
  }
}

void drawGround() {
  stroke(0);
  strokeWeight(2);
  line(0, 0.8 * height, width, 0.8 * height);
}

void keyPressed() {
  switch (key) {
    case 'w':
      controller.up(true);
      break;
    case 'a':
      controller.left(true);
      break;
    case 's':
      controller.down(true);
      break;
    case 'd':
      controller.right(true);
      break;
    case CODED:
      if (keyCode == SHIFT) {
        controller.isRunning(true);
      }
      break;
  }
}


void keyReleased() {
  switch (key) {
    case 'w':
      controller.up(false);
      break;
    case 'a':
      controller.left(false);
      break;
    case 's':
      controller.down(false);
      break;
    case 'd':
      controller.right(false);
      break;
    case CODED:
      if (keyCode == SHIFT) {
        controller.isRunning(false);
      }
      break;
  }
}
