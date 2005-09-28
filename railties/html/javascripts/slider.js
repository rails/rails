// Copyright (c) 2005 Marty Haught
// 
// See scriptaculous.js for full license.

if(!Control) var Control = {};
Control.Slider = Class.create();

// options:
//  axis: 'vertical', or 'horizontal' (default)
//  increment: (default: 1)
//  step: (default: 1)
//
// callbacks:
//  onChange(value)
//  onSlide(value)
Control.Slider.prototype = {
  initialize: function(handle, track, options) {
    this.handle  = $(handle);
    this.track   = $(track);

    this.options = options || {};

    this.axis      = this.options.axis || 'horizontal';
    this.increment = this.options.increment || 1;
    this.step      = parseInt(this.options.step) || 1;
    this.value     = 0;

    var defaultMaximum = Math.round(this.track.offsetWidth / this.increment);
    if(this.isVertical()) defaultMaximum = Math.round(this.track.offsetHeight / this.increment);   
    
    this.maximum = this.options.maximum || defaultMaximum;
    this.minimum = this.options.minimum || 0;

    // Will be used to align the handle onto the track, if necessary
    this.alignX = parseInt (this.options.alignX) || 0;
    this.alignY = parseInt (this.options.alignY) || 0;

    // Zero out the slider position	
    this.setCurrentLeft(Position.cumulativeOffset(this.track)[0] - Position.cumulativeOffset(this.handle)[0] + this.alignX);
    this.setCurrentTop(this.trackTop() - Position.cumulativeOffset(this.handle)[1] + this.alignY);

    this.offsetX = 0;
    this.offsetY = 0;

    this.originalLeft = this.currentLeft();
    this.originalTop  = this.currentTop();
    this.originalZ    = parseInt(this.handle.style.zIndex || "0");

    // Prepopulate Slider value
    this.setSliderValue(parseInt(this.options.sliderValue) || 0);

    this.active   = false;
    this.dragging = false;
    this.disabled = false;

    // FIXME: use css
    this.handleImage    = $(this.options.handleImage) || false; 
    this.handleDisabled = this.options.handleDisabled || false;
    this.handleEnabled  = false;
    if(this.handleImage)
      this.handleEnabled  = this.handleImage.src || false;

    if(this.options.disabled)
      this.setDisabled();

    // Value Array
    this.values = this.options.values || false;  // Add method to validate and sort??

    Element.makePositioned(this.handle); // fix IE

    this.eventMouseDown = this.startDrag.bindAsEventListener(this);
    this.eventMouseUp   = this.endDrag.bindAsEventListener(this);
    this.eventMouseMove = this.update.bindAsEventListener(this);
    this.eventKeypress  = this.keyPress.bindAsEventListener(this);

    Event.observe(this.handle, "mousedown", this.eventMouseDown);
    Event.observe(document, "mouseup", this.eventMouseUp);
    Event.observe(document, "mousemove", this.eventMouseMove);
    Event.observe(document, "keypress", this.eventKeypress);
  },
  dispose: function() {
    Event.stopObserving(this.handle, "mousedown", this.eventMouseDown);
    Event.stopObserving(document, "mouseup", this.eventMouseUp);
    Event.stopObserving(document, "mousemove", this.eventMouseMove);
    Event.stopObserving(document, "keypress", this.eventKeypress);
  },
  setDisabled: function(){
    this.disabled = true;
    if(this.handleDisabled)
      this.handleImage.src = this.handleDisabled;
  },
  setEnabled: function(){
    this.disabled = false;
    if(this.handleEnabled)
      this.handleImage.src = this.handleEnabled;
  },  
  currentLeft: function() {
    return parseInt(this.handle.style.left || '0');
  },
  currentTop: function() {
    return parseInt(this.handle.style.top || '0');
  },
  setCurrentLeft: function(left) {
    this.handle.style.left = left +"px";
  },
  setCurrentTop: function(top) {
    this.handle.style.top = top +"px";
  },
  trackLeft: function(){
    return Position.cumulativeOffset(this.track)[0];
  },
  trackTop: function(){
    return Position.cumulativeOffset(this.track)[1];
  }, 
  getNearestValue: function(value){
    if(this.values){
      var i = 0;
      var offset = Math.abs(this.values[0] - value);
      var newValue = this.values[0];

      for(i=0; i < this.values.length; i++){
        var currentOffset = Math.abs(this.values[i] - value);
        if(currentOffset < offset){
          newValue = this.values[i];
          offset = currentOffset;
        }
      }
      return newValue;
    }
    return value;
  },
  setSliderValue:  function(sliderValue){
    // First check our max and minimum and nearest values
    sliderValue = this.getNearestValue(sliderValue);	
    if(sliderValue > this.maximum) sliderValue = this.maximum;
    if(sliderValue < this.minimum) sliderValue = this.minimum;
    var offsetDiff = (sliderValue - (this.value||this.minimum)) * this.increment;
    
    if(this.isVertical()){
      this.setCurrentTop(offsetDiff + this.currentTop());
    } else {
      this.setCurrentLeft(offsetDiff + this.currentLeft());
    }
    this.value = sliderValue;
    this.updateFinished();
  },  
  minimumOffset: function(){
    return(this.isVertical() ? 
      this.trackTop() + this.alignY :
      this.trackLeft() + this.alignX);
  },
  maximumOffset: function(){
    return(this.isVertical() ?
      this.trackTop() + this.alignY + (this.maximum - this.minimum) * this.increment :
      this.trackLeft() + this.alignX + (this.maximum - this.minimum) * this.increment);
  },  
  isVertical:  function(){
    return (this.axis == 'vertical');
  },
  startDrag: function(event) {
    if(Event.isLeftClick(event)) {
      if(!this.disabled){
        this.active = true;
        var pointer = [Event.pointerX(event), Event.pointerY(event)];
        var offsets = Position.cumulativeOffset(this.handle);
        this.offsetX =  (pointer[0] - offsets[0]);
        this.offsetY =  (pointer[1] - offsets[1]);
        this.originalLeft = this.currentLeft();
        this.originalTop = this.currentTop();
      }
      Event.stop(event);
    }
  },
  update: function(event) {
   if(this.active) {
      if(!this.dragging) {
        var style = this.handle.style;
        this.dragging = true;
        if(style.position=="") style.position = "relative";
        style.zIndex = this.options.zindex;
      }
      this.draw(event);
      // fix AppleWebKit rendering
      if(navigator.appVersion.indexOf('AppleWebKit')>0) window.scrollBy(0,0);
      Event.stop(event);
   }
  },
  draw: function(event) {
    var pointer = [Event.pointerX(event), Event.pointerY(event)];
    var offsets = Position.cumulativeOffset(this.handle);

    offsets[0] -= this.currentLeft();
    offsets[1] -= this.currentTop();
        
    // Adjust for the pointer's position on the handle
    pointer[0] -= this.offsetX;
    pointer[1] -= this.offsetY;
    var style = this.handle.style;

    if(this.isVertical()){
      if(pointer[1] > this.maximumOffset())
        pointer[1] = this.maximumOffset();
      if(pointer[1] < this.minimumOffset())
        pointer[1] =  this.minimumOffset();

    // Increment by values
    if(this.values){
      this.value = this.getNearestValue(Math.round((pointer[1] - this.minimumOffset()) / this.increment) + this.minimum);
      pointer[1] = this.trackTop() + this.alignY + (this.value - this.minimum) * this.increment;
    } else {
      this.value = Math.round((pointer[1] - this.minimumOffset()) / this.increment) + this.minimum;
    }
    style.top  = pointer[1] - offsets[1] + "px";
    } else {
      if(pointer[0] > this.maximumOffset()) pointer[0] = this.maximumOffset();
      if(pointer[0] < this.minimumOffset())	pointer[0] =  this.minimumOffset();
      // Increment by values
      if(this.values){
        this.value = this.getNearestValue(Math.round((pointer[0] - this.minimumOffset()) / this.increment) + this.minimum);
        pointer[0] = this.trackLeft() + this.alignX + (this.value - this.minimum) * this.increment;
      } else {
        this.value = Math.round((pointer[0] - this.minimumOffset()) / this.increment) + this.minimum;
      }
      style.left = (pointer[0] - offsets[0]) + "px";
    }
    if(this.options.onSlide) this.options.onSlide(this.value);
  },
  endDrag: function(event) {
    if(this.active && this.dragging) {
      this.finishDrag(event, true);
      Event.stop(event);
    }
    this.active = false;
    this.dragging = false;
  },  
  finishDrag: function(event, success) {
    this.active = false;
    this.dragging = false;
    this.handle.style.zIndex = this.originalZ;
    this.originalLeft = this.currentLeft();
    this.originalTop  = this.currentTop();
    this.updateFinished();
  },
  updateFinished: function() {
    if(this.options.onChange) this.options.onChange(this.value);
  },
  keyPress: function(event) {
    if(this.active && !this.disabled) {
      switch(event.keyCode) {
        case Event.KEY_ESC:
          this.finishDrag(event, false);
          Event.stop(event); 
          break;
      }
      if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
    }
  }
}
