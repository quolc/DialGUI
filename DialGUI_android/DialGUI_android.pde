TouchProcessor touch;

Item root;
ArrayList<Item> stack = new ArrayList<Item>();

boolean transition = false;
float progress = 1;
int transition_steps = 20;
int trans = 0;

float velocity = 0.0;
float fliction = 0.01;
float valley = 0.01;
float valleythreshold = TWO_PI/360*3;

float eps = 0.0001;

float center_x=width/2;
float center_y=height/2;

boolean dragging = false;

void setup() {  
  // drawing settings
  size(480, 800);
  ellipseMode(CENTER);
  colorMode(HSB, 360);
  smooth();
  noStroke();
  
  touch = new TouchProcessor();
  
  root = new Item(color(0, 0, 360));
  
  for (int i=0; i<12; i++) {
    Item item = new Item(color(360.0/12*i, 360, 360));
    for (int j=0; j<12; j++) {
      Item item2 = new Item(color(360.0/12*i, 360.0/12*(12-j), 360));
      for (int k=0; k<12; k++) {
        item2.children.add(new Item(color(360.0/12*i, 360.0/12*(12-j), 360.0/12*(12-k))));
      }
      item.children.add(item2);
    }
    root.children.add(item);
  }
  
  stack.add(root);
  background(0);
}

void draw() {
  fill(0,0,0,30);
  rect(0,0,width,height);

  dragging = false;
  touch.analyse();
  touch.sendEvents();
  
  Item current = stack.get(stack.size()-1);
  
  center_x = current.pos.x + (width/2 - current.pos.x) * progress;
  center_y = current.pos.y + (height/2 - current.pos.y) * progress;
  float whole_rad = current.rad + (width-6 - current.rad) * progress;
  
  if (current.children.size()>0) {
    fill(current.c, 240);
    ellipse(center_x, center_y, whole_rad, whole_rad);
    fill(0);
    ellipse(center_x, center_y, whole_rad-6, whole_rad-6);
  } else {
    fill(current.c, 360);
    ellipse(center_x, center_y, whole_rad, whole_rad);
  }
  if(transition) {
    current.rotation -= TWO_PI/transition_steps;
  }
  
  for(int i=0; i<current.children.size(); i++) {
    Item item = current.children.get(i);
    
    float theta = (TWO_PI/current.children.size()*i + current.rotation)%TWO_PI;

    item.pos = new PVector(center_x + 240*sin(theta)*progress,
                              center_y - 240*cos(theta)*progress);
    item.rad = calcrad(item.pos)*progress;
    item.pos = transform(item.pos);
    item.pos = shortening(item.pos, item.rad/2+10);
    
    fill(item.c);
    if(!transition || i<current.children.size()*progress) {
      ellipse(item.pos.x, item.pos.y, item.rad, item.rad);
    }
  }
  
  // back button
  if (stack.size() > 1) {
    fill(stack.get(stack.size()-2).c, 240);
    ellipse(center_x, center_y, 120*progress, 120*progress);
    fill(0);
    ellipse(center_x, center_y, 114*progress, 114*progress);
  }

  // fliction
  if (velocity < 0) {
    velocity += fliction;
    if (velocity > 0) velocity = 0;
  } else {
    velocity -= fliction; 
    if (velocity < 0) velocity = 0;
  }
  
  // valley effect
  if (!dragging && velocity < valleythreshold) {
    velocity += -sin(current.rotation*current.children.size())*valley;
  }
  
  current.rotation += velocity;
  
  if(transition) {
    trans++;
    progress = sigmoid(4.0*(float)trans/transition_steps*2-1.0);
    if(trans == transition_steps) {
      progress = 1;
      transition = false;
    }
  }
}

float sigmoid(float x) {
  return 1.0/(1+exp(-x));
}

float calcTheta(PVector pos) {
  float theta = atan((pos.x-center_x+eps) / (center_y-pos.y+eps));
  float margin = 10.0;
  if (theta > 0 && pos.x <= center_x+margin && pos.y >= center_y-margin) theta += PI;
  if (theta < 0) {
    if (pos.x >= center_x-margin && pos.y >= center_y-margin) theta += PI;
    else theta += TWO_PI;
  }
  return theta;
}

PVector transform(PVector pos) {
  float theta = calcTheta(pos);
  float r = sqrt( sq(pos.x-center_x) + sq(pos.y-center_y));
  
  float newtheta = 0;
  if (theta < PI) {
    newtheta = PI * pow(sin(theta/2), 0.9);
  } else {
    newtheta = TWO_PI - PI * pow(sin(theta/2), 0.9);
  }
  
  return new PVector(center_x + r*sin(newtheta), center_y - r*cos(newtheta));
}

PVector shortening(PVector pos, float len) {
  float theta = calcTheta(pos);
  float r = sqrt( sq(pos.x-center_x) + sq(pos.y-center_y));
  
  return new PVector(center_x + (r-len)*sin(theta), center_y - (r-len)*cos(theta));
}

float calcrad(PVector pos) {
  float max_rad = 160;
  float min_rad = 40;
  float theta = calcTheta(pos);
  
  return max_rad - (max_rad - min_rad) * pow(sin(theta/2), 0.75);
}

class Item {
  ArrayList<Item> children;
  color c;
  float rotation;
  
  PVector pos;
  float theta;
  float rad;
    
  public Item(color c) {
    this.c = c;
    this.children = new ArrayList<Item>();
    this.rotation = eps;
    this.pos = new PVector(width/2, height/2);
    this.rad = 474;
  }
  
  public Item(Item[] children, color c) {
    this(c);
    for(int i=0; i<children.length; i++) {
      this.children.add(children[i]);
    }
  }
}

//-------------------------------------------------------------------------------------
// MULTI TOUCH EVENTS!

void onTap( TapEvent event ) {
  PVector epos = new PVector(event.x, event.y);
  if(!transition) {
    Item current = stack.get(stack.size()-1);
    for (int i=0; i<current.children.size(); i++) {
      Item item = current.children.get(i);
      if (epos.dist(item.pos) < item.rad/2) {
        println(i);
        this.stack.add(item);
        transition = true;
        velocity = 0;
        progress = 0;
        trans = 0;
        item.rotation = current.rotation + TWO_PI/current.children.size()*i;
        return;
      }
    }
    
    if (stack.size()>1 && epos.dist(new PVector(center_x, center_y)) < 60.0) {
      this.stack.remove(this.stack.size()-1);
      transition = true;
      velocity = 0;
      progress = 0;
      trans = 0;
      return;
    }
  }
}

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void onFlick( FlickEvent event ) {
}

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void onDrag( DragEvent event ) {
  if(!transition) {
    if (event.numberOfPoints == 1) {
      dragging = true;
      PVector position = new PVector(event.x-width/2, event.y-height/2);
      if (100 < position.mag() && position.mag() < 260) {
        position = new PVector(-position.y, position.x);
        position.normalize();
        float product = position.dot(new PVector(event.dx, event.dy));
  //      rotation += product/(width)*PI;
        velocity = product/(width)*PI/4*3;
      }
    }
  }
}

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void onRotate( RotateEvent event ) {
}

//- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
void onPinch( PinchEvent event ) {
}

//-------------------------------------------------------------------------------------
// This is the stock Android touch event 
boolean surfaceTouchEvent(MotionEvent event) {
  
  // extract the action code & the pointer ID
  int action = event.getAction();
  int code   = action & MotionEvent.ACTION_MASK;
  int index  = action >> MotionEvent.ACTION_POINTER_ID_SHIFT;

  float x = event.getX(index);
  float y = event.getY(index);
  int id  = event.getPointerId(index);

  // pass the events to the TouchProcessor
  if ( code == MotionEvent.ACTION_DOWN || code == MotionEvent.ACTION_POINTER_DOWN) {
    touch.pointDown(x, y, id);
  }
  else if (code == MotionEvent.ACTION_UP || code == MotionEvent.ACTION_POINTER_UP) {
    touch.pointUp(event.getPointerId(index));
  }
  else if ( code == MotionEvent.ACTION_MOVE) {
    int numPointers = event.getPointerCount();
    for (int i=0; i < numPointers; i++) {
      id = event.getPointerId(i);
      x = event.getX(i);
      y = event.getY(i);
      touch.pointMoved(x, y, id);
    }
  } 

  return super.surfaceTouchEvent(event);
}
