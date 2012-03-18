// Event classes
///////////////////////////////////////////////////////////////////////////////////
class TouchEvent {
  // empty base class to make event handling easier
}

///////////////////////////////////////////////////////////////////////////////////
class DragEvent extends TouchEvent {

  float x; // position
  float y;
  float dx; // movement 
  float dy; 
  int numberOfPoints;

  DragEvent(float x, float y, float dx, float dy, int n) {
    this.x = x;
    this.y = y;
    this.dx = dx;
    this.dy = dy;
    numberOfPoints = n;
  }
}

///////////////////////////////////////////////////////////////////////////////////
class PinchEvent extends TouchEvent {

  float centerX;
  float centerY;
  float amount; // in pixels
  int numberOfPoints;

  PinchEvent(float centerX, float centerY, float amount, int n) {
    this.centerX = centerX;
    this.centerY = centerY;  
    this.amount = amount;
  }
}

///////////////////////////////////////////////////////////////////////////////////
class RotateEvent extends TouchEvent {  

  float centerX;
  float centerY;
  float angle; // delta, in radians
  int numberOfPoints;

  RotateEvent(float centerX, float centerY, float angle, int n) {
    this.centerX = centerX;
    this.centerY = centerY;  
    this.angle = angle;
  }
}


///////////////////////////////////////////////////////////////////////////////////
class TapEvent extends TouchEvent {

  public static final int SINGLE = 0;
  public static final int DOUBLE = 1;

  float x;
  float y;
  int type;

  TapEvent(float x, float y, int type) {
    this.x = x;
    this.y = y;
    this.type = type;
  }  

  boolean isSingleTap() {
    return (type == SINGLE) ? true : false;
  }

  boolean isDoubleTap() {
    return (type == DOUBLE) ? true : false;
  }
}

///////////////////////////////////////////////////////////////////////////////////
class FlickEvent extends TouchEvent { 

  float x;
  float y;
  PVector velocity;

  FlickEvent(float x, float y, PVector velocity) {
    this.x = x; 
    this.y = y;
    this.velocity = velocity;
  }
}

class TouchPoint {
  
  float x;
  float y;
  float px;
  float py;
  int id;
  
  // used for gesture detection
  float angle;
  float oldAngle;  
  float pinch;
  float oldPinch;

  //-------------------------------------------------------------------------------------
  TouchPoint(float x, float y, int id) {
    this.x = x;
    this.y = y;
    this.px = x;
    this.py = y;
    this.id = id;  
  }

  //------------------------------------------------------------------------------
  void update(float x, float y) {
    px = this.x;
    py = this.y;
    this.x = x;
    this.y = y;
  }

  //-------------------------------------------------------------------------------------
  void initGestureData(float cx, float cy) {  
    pinch = oldPinch = dist(x, y, cx, cy);
    angle = oldAngle = atan2( (y-cy), (x-cx) );
  }
 
  //-------------------------------------------------------------------------------------
  // delta x -- int to get rid of some noise
  int dx() {
    return int(x - px);
  }
  
  //-------------------------------------------------------------------------------------
  // delta y -- int to get rid of some noise
  int dy() {
    return int(y - py);
  } 
  
  //-------------------------------------------------------------------------------------
  void setAngle(float angle) {
    oldAngle = this.angle;  
    this.angle = angle;
  }
  
  //-------------------------------------------------------------------------------------
  void setPinch(float pinch) {
     oldPinch = this.pinch;
     this.pinch = pinch; 
  }

}
// TODO: make distance thershold based on pixel density information!

class TouchProcessor {

  // heuristic constants 
  long  TAP_INTERVAL = 200;
  long  TAP_TIMEOUT  = 200;
  int   DOUBLE_TAP_DIST_THRESHOLD = 30;
  int   FLICK_VELOCITY_THRESHOLD = 20;
  float MAX_MULTI_DRAG_DISTANCE = 100; // from the centroid

  // A list of currently active touch points 
  ArrayList touchPoints;

  // Used for tap/doubletaps 
  TouchPoint firstTap;
  TouchPoint secondTap;
  long tap;
  int tapCount = 0;

  // Events to be broadcast to the sketch 
  ArrayList events;

  // centroid information
  float cx, cy;
  float old_cx, old_cy;
  
  boolean pointsChanged = false;

  //-------------------------------------------------------------------------------------
  TouchProcessor() {
    touchPoints = new ArrayList();
    events = new ArrayList();
  }

  //-------------------------------------------------------------------------------------
  // Point Update functions 
  synchronized void pointDown(float x, float y, int id) {    
    TouchPoint p = new TouchPoint(x, y, id);
    touchPoints.add(p);  
    
    updateCentroid();
    if ( touchPoints.size() >= 2) {
      p.initGestureData(cx, cy);
      if (touchPoints.size() == 2) {
        // if this is the second point, we now have a valid centroid to update the first point
        TouchPoint frst = (TouchPoint)touchPoints.get(0);
        frst.initGestureData(cx, cy);
      }
    }

    // tap detection 
    if (tapCount == 0) {
      firstTap = p;
    }
    if (tapCount == 1) {
      secondTap = p;
    }
    tap = millis();
    pointsChanged = true;
  }

  //-------------------------------------------------------------------------------------
  synchronized void pointUp(int id) {
    TouchPoint p = getPoint(id);
    touchPoints.remove(p);

    // tap detection 
    // TODO: handle a long press event here? 
    if ( p == firstTap || p == secondTap ) {
      // this could be either a Tap or a Flick gesture, based on movement 
      float d = dist(p.x, p.y, p.px, p.py);
      if ( d > FLICK_VELOCITY_THRESHOLD ) {
        FlickEvent event = new FlickEvent(p.px, p.py, new PVector(p.x-p.px, p.y-p.py));
        events.add(event);
      }
      else {      
        long interval = millis() - tap;
        if ( interval < TAP_INTERVAL ) {
          tapCount++;
        }
      }
    }
    pointsChanged = true;
  }

  //-------------------------------------------------------------------------------------
  synchronized void pointMoved(float x, float y, int id) {
    TouchPoint p = getPoint(id);
    p.update(x, y);
    // since the events will be in sync with draw(), we just wait until analyse() to
    // look for gestures
    pointsChanged = true;
  }

  //-------------------------------------------------------------------------------------
  // Calculate the centroid of all active points 
  void updateCentroid() {
    old_cx = cx;
    old_cy = cy;
    cx = 0;
    cy = 0;
    for (int i=0; i < touchPoints.size(); i++) {
      TouchPoint p = (TouchPoint)touchPoints.get(i);
      cx += p.x;
      cy += p.y;
    }
    cx /= touchPoints.size();
    cy /= touchPoints.size(); 
  }

  //-------------------------------------------------------------------------------------
  synchronized void analyse() {
    handleTaps();
    // simple event priority rule: do not try to rotate or pinch while dragging
    // this gets rid of a lot of jittery events 
    if (pointsChanged) {
      updateCentroid();
      if (handleDrag() == false) {
        handleRotation();
        handlePinch();
      }
      pointsChanged = false;
    }
  }


  //-------------------------------------------------------------------------------------
  // send events to the sketch
  void sendEvents() {
    for (int i=0; i < events.size(); i++) {
      TouchEvent e = (TouchEvent)events.get(i);
      if      ( e instanceof TapEvent ) onTap( (TapEvent)e );
      else if ( e instanceof FlickEvent ) onFlick( (FlickEvent)e );
      else if ( e instanceof DragEvent ) onDrag( (DragEvent)e );
      else if ( e instanceof PinchEvent ) onPinch( (PinchEvent)e );
      else if ( e instanceof RotateEvent ) onRotate( (RotateEvent)e );
    }
    events.clear();
  }

  //-------------------------------------------------------------------------------------
  void handleTaps() {
    if (tapCount == 2) {
      // check if the tap point has moved 
      float d = dist(firstTap.x, firstTap.y, secondTap.x, secondTap.y);
      if ( d > DOUBLE_TAP_DIST_THRESHOLD ) {
        // if the two taps are apart, count them as two single taps
        TapEvent event1 = new TapEvent(firstTap.x, firstTap.y, TapEvent.SINGLE);        
        onTap(event1);
        TapEvent event2 = new TapEvent(secondTap.x, secondTap.y, TapEvent.SINGLE);        
        onTap(event2);
      }
      else {
        events.add( new TapEvent(firstTap.x, firstTap.y, TapEvent.DOUBLE) );
      }
      tapCount = 0;
    }
    else if (tapCount == 1) { 
      long interval = millis() - tap;
      if (interval > TAP_TIMEOUT) {
        events.add( new TapEvent(firstTap.x, firstTap.y, TapEvent.SINGLE) );               
        tapCount = 0;
      }
    }
  }

  //-------------------------------------------------------------------------------------
  // rotation is the average angle change between each point and the centroid 
  void handleRotation() {
    if (touchPoints.size() < 2) return;
    // look for rotation events
    float rotation = 0;
    for (int i=0; i < touchPoints.size(); i++) {
      TouchPoint p = (TouchPoint)touchPoints.get(i);
      float angle = atan2( p.y-cy, p.x-cx );
      p.setAngle(angle);
      float delta = p.angle - p.oldAngle;
      if ( delta > PI ) delta -= TWO_PI;
      if ( delta < -PI ) delta += TWO_PI;
      rotation += delta;
    } 
    rotation /= touchPoints.size() ;
    if ( rotation != 0 ) events.add( new RotateEvent(cx, cy, rotation, touchPoints.size()) );
  }

  //-------------------------------------------------------------------------------------
  // pinch is simply the average distance change from each points to the centroid
  void handlePinch() {
    if (touchPoints.size() < 2) return;
    // look for pinch events 
    float pinch = 0;
    for (int i=0; i < touchPoints.size(); i++) {
      TouchPoint p = (TouchPoint)touchPoints.get(i);
      float distance = dist(p.x, p.y, cx, cy);
      p.setPinch(distance);
      float delta = p.pinch - p.oldPinch;
      pinch += delta;
    }
    pinch /= touchPoints.size(); 
    if (pinch != 0) events.add( new PinchEvent(cx, cy, pinch, touchPoints.size()) );
  }

  //-------------------------------------------------------------------------------------
  boolean handleDrag() {
    // look for multi-finger drag events
    // multi-drag is defined as all the fingers moving close-ish together in the same direction
    boolean x_drag = true;
    boolean y_drag = true;
    boolean clustered = false;
    int first_x_dir = 0;
    int first_y_dir = 0;

    for (int i=0; i < touchPoints.size(); i++) {
      TouchPoint p = (TouchPoint)touchPoints.get(i);
      int x_dir = 0;
      int y_dir = 0;
      if (p.dx() > 0) x_dir = 1;
      if (p.dx() < 0) x_dir = -1;
      if (p.dy() > 0) y_dir = 1;
      if (p.dy() < 0) y_dir = -1;

      if (i==0) {
        first_x_dir = x_dir;
        first_y_dir = y_dir;
      }
      else {
        if (first_x_dir != x_dir) x_drag = false;
        if (first_y_dir != y_dir) y_drag = false;
      }

      // if the point is stationary 
      if (x_dir == 0) x_drag = false;
      if (y_dir == 0) y_drag = false;
      
      if (touchPoints.size() == 1) clustered = true;
      else {
        float distance = dist(p.x, p.y, cx, cy);
        if ( distance < MAX_MULTI_DRAG_DISTANCE ) {
          clustered = true;
        }
      }
    }

    if ((x_drag || y_drag) && clustered) {
      if (touchPoints.size() == 1) {
        TouchPoint p = (TouchPoint)touchPoints.get(0);
        // use the centroid to calculate the position and delta of this drag event
        events.add(new DragEvent(p.x, p.y, p.dx(), p.dy(), 1));
      }
      else {  
        // use the centroid to calculate the position and delta of this drag event
        events.add(new DragEvent(cx, cy, cx-old_cx, cy-old_cy, touchPoints.size()));
      }
      return true;
    }
    return false;
  }

  //-------------------------------------------------------------------------------------
  synchronized ArrayList getPoints() {
    return (ArrayList)touchPoints.clone();
  }

  //-------------------------------------------------------------------------------------
  synchronized TouchPoint getPoint(int pid) {
    Iterator i = touchPoints.iterator();
    while (i.hasNext ()) {
      TouchPoint tp = (TouchPoint)i.next();
      if (tp.id == pid) return tp;
    }
    return null;
  }
 
}

