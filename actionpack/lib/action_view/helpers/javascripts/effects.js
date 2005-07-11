// Copyright (c) 2005 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//
// Parts (c) 2005 Justin Palmer (http://encytemedia.com/)
// Parts (c) 2005 Mark Pilgrim (http://diveintomark.org/)
// 
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
// 
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


Effect = {}
Effect2 = Effect; // deprecated

/* ------------- transitions ------------- */

Effect.Transitions = {}

Effect.Transitions.linear = function(pos) {
  return pos;
}
Effect.Transitions.sinoidal = function(pos) {
  return (-Math.cos(pos*Math.PI)/2) + 0.5;
}
Effect.Transitions.reverse  = function(pos) {
  return 1-pos;
}
Effect.Transitions.flicker = function(pos) {
  return ((-Math.cos(pos*Math.PI)/4) + 0.75) + Math.random(0.25);
}
Effect.Transitions.wobble = function(pos) {
  return (-Math.cos(pos*Math.PI*(9*pos))/2) + 0.5;
}
Effect.Transitions.pulse = function(pos) {
  return (Math.floor(pos*10) % 2 == 0 ? 
    (pos*10-Math.floor(pos*10)) : 1-(pos*10-Math.floor(pos*10)));
}
Effect.Transitions.none = function(pos) {
  return 0;
}
Effect.Transitions.full = function(pos) {
  return 1;
}

/* ------------- element ext -------------- */

Element.makePositioned = function(element) {
  element = $(element);
  if(element.style.position == "")
    element.style.position = "relative";
}

Element.makeClipping = function(element) {
  element = $(element);
  element._overflow = element.style.overflow || 'visible';
  if(element._overflow!='hidden') element.style.overflow = 'hidden';
}

Element.undoClipping = function(element) {
  element = $(element);
  if(element._overflow!='hidden') element.style.overflow = element._overflow;
}

/* ------------- core effects ------------- */

Effect.Base = function() {};
Effect.Base.prototype = {
  setOptions: function(options) {
    this.options = Object.extend({
      transition: Effect.Transitions.sinoidal,
      duration:   1.0,   // seconds
      fps:        25.0,  // max. 100fps
      sync:       false, // true for combining
      from:       0.0,
      to:         1.0
    }, options || {});
  },
  start: function(options) {
    this.setOptions(options || {});
    this.currentFrame = 0;
    this.startOn      = new Date().getTime();
    this.finishOn     = this.startOn + (this.options.duration*1000);
    if(this.options.beforeStart) this.options.beforeStart(this);
    if(!this.options.sync) this.loop();  
  },
  loop: function() {
    var timePos = new Date().getTime();
    if(timePos >= this.finishOn) {
      this.render(this.options.to);
      if(this.finish) this.finish(); 
      if(this.options.afterFinish) this.options.afterFinish(this);
      return;  
    }
    var pos   = (timePos - this.startOn) / (this.finishOn - this.startOn);
    var frame = Math.round(pos * this.options.fps * this.options.duration);
    if(frame > this.currentFrame) {
      this.render(pos);
      this.currentFrame = frame;
    }
    this.timeout = setTimeout(this.loop.bind(this), 10);
  },
  render: function(pos) {
    if(this.options.transition) pos = this.options.transition(pos);
    pos *= (this.options.to-this.options.from);
    pos += this.options.from; 
    if(this.options.beforeUpdate) this.options.beforeUpdate(this);
    if(this.update) this.update(pos);
    if(this.options.afterUpdate) this.options.afterUpdate(this);  
  },
  cancel: function() {
    if(this.timeout) clearTimeout(this.timeout);
  }
}

Effect.Parallel = Class.create();
Object.extend(Object.extend(Effect.Parallel.prototype, Effect.Base.prototype), {
  initialize: function(effects) {
    this.effects = effects || [];
    this.start(arguments[1]);
  },
  update: function(position) {
    for (var i = 0; i < this.effects.length; i++)
      this.effects[i].render(position);  
  },
  finish: function(position) {
    for (var i = 0; i < this.effects.length; i++)
      if(this.effects[i].finish) this.effects[i].finish(position);
  }
});

// Internet Explorer caveat: works only on elements the have
// a 'layout', meaning having a given width or height. 
// There is no way to safely set this automatically.
Effect.Opacity = Class.create();
Object.extend(Object.extend(Effect.Opacity.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    options = Object.extend({
      from: 0.0,
      to:   1.0
    }, arguments[1] || {});
    this.start(options);
  },
  update: function(position) {
    this.setOpacity(position);
  }, 
  setOpacity: function(opacity) {
    opacity = (opacity == 1) ? 0.99999 : opacity;
    this.element.style.opacity = opacity;
    this.element.style.filter = "alpha(opacity:"+opacity*100+")";
  }
});

Effect.MoveBy = Class.create();
Object.extend(Object.extend(Effect.MoveBy.prototype, Effect.Base.prototype), {
  initialize: function(element, toTop, toLeft) {
    this.element      = $(element);
    this.originalTop  = parseFloat(this.element.style.top || '0');
    this.originalLeft = parseFloat(this.element.style.left || '0');
    this.toTop        = toTop;
    this.toLeft       = toLeft;
    Element.makePositioned(this.element);
    this.start(arguments[3]);
  },
  update: function(position) {
    topd  = this.toTop  * position + this.originalTop;
    leftd = this.toLeft * position + this.originalLeft;
    this.setPosition(topd, leftd);
  },
  setPosition: function(topd, leftd) {
    this.element.style.top  = topd  + "px";
    this.element.style.left = leftd + "px";
  }
});

Effect.Scale = Class.create();
Object.extend(Object.extend(Effect.Scale.prototype, Effect.Base.prototype), {
  initialize: function(element, percent) {
    this.element = $(element)
    options = Object.extend({
      scaleX: true,
      scaleY: true,
      scaleContent: true,
      scaleFromCenter: false,
      scaleMode: 'box',        // 'box' or 'contents' or {} with provided values
      scaleFrom: 100.0
    }, arguments[2] || {});
    this.originalTop    = this.element.offsetTop;
    this.originalLeft   = this.element.offsetLeft;
    if(this.element.style.fontSize=="") this.sizeEm = 1.0;
    if(this.element.style.fontSize && this.element.style.fontSize.indexOf("em")>0)
      this.sizeEm      = parseFloat(this.element.style.fontSize);
    this.factor = (percent/100.0) - (options.scaleFrom/100.0);
    if(options.scaleMode=='box') {
      this.originalHeight = this.element.clientHeight;
      this.originalWidth  = this.element.clientWidth; 
    } else 
    if(options.scaleMode=='contents') {
      this.originalHeight = this.element.scrollHeight;
      this.originalWidth  = this.element.scrollWidth;
    } else {
      this.originalHeight = options.scaleMode.originalHeight;
      this.originalWidth  = options.scaleMode.originalWidth;
    }
    this.start(options);
  },

  update: function(position) {
    currentScale = (this.options.scaleFrom/100.0) + (this.factor * position);
    if(this.options.scaleContent && this.sizeEm) 
      this.element.style.fontSize = this.sizeEm*currentScale + "em";
    this.setDimensions(
      this.originalWidth * currentScale, 
      this.originalHeight * currentScale);
  },

  setDimensions: function(width, height) {
    if(this.options.scaleX) this.element.style.width = width + 'px';
    if(this.options.scaleY) this.element.style.height = height + 'px';
    if(this.options.scaleFromCenter) {
      topd  = (height - this.originalHeight)/2;
      leftd = (width  - this.originalWidth)/2;
      if(this.element.style.position=='absolute') {
        if(this.options.scaleY) this.element.style.top = this.originalTop-topd + "px";
        if(this.options.scaleX) this.element.style.left = this.originalLeft-leftd + "px";
      } else {
        if(this.options.scaleY) this.element.style.top = -topd + "px";
        if(this.options.scaleX) this.element.style.left = -leftd + "px";
      }
    }
  }
});

Effect.Highlight = Class.create();
Object.extend(Object.extend(Effect.Highlight.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    
    // try to parse current background color as default for endcolor
    // browser stores this as: "rgb(255, 255, 255)", convert to "#ffffff" format
    var endcolor = "#ffffff";
    var current = this.element.style.backgroundColor;
    if(current && current.slice(0,4) == "rgb(") {
      endcolor = "#";
      var cols = current.slice(4,current.length-1).split(',');
      var i=0; do { endcolor += parseInt(cols[i]).toColorPart() } while (++i<3); }
      
    var options = Object.extend({
      startcolor:   "#ffff99",
      endcolor:     endcolor,
      restorecolor: current 
    }, arguments[1] || {});
    
    // init color calculations
    this.colors_base = [
      parseInt(options.startcolor.slice(1,3),16),
      parseInt(options.startcolor.slice(3,5),16),
      parseInt(options.startcolor.slice(5),16) ];
    this.colors_delta = [
      parseInt(options.endcolor.slice(1,3),16)-this.colors_base[0],
      parseInt(options.endcolor.slice(3,5),16)-this.colors_base[1],
      parseInt(options.endcolor.slice(5),16)-this.colors_base[2] ];

    this.start(options);
  },
  update: function(position) {
    var colors = [
      Math.round(this.colors_base[0]+(this.colors_delta[0]*position)),
      Math.round(this.colors_base[1]+(this.colors_delta[1]*position)),
      Math.round(this.colors_base[2]+(this.colors_delta[2]*position)) ];
    this.element.style.backgroundColor = "#" +
      colors[0].toColorPart() + colors[1].toColorPart() + colors[2].toColorPart();
  },
  finish: function() {
    this.element.style.backgroundColor = this.options.restorecolor;
  }
});

Effect.ScrollTo = Class.create();
Object.extend(Object.extend(Effect.ScrollTo.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    Position.prepare();
    var offsets = Position.cumulativeOffset(this.element);
    var max = window.innerHeight ? 
      window.height - window.innerHeight :
      document.body.scrollHeight - 
        (document.documentElement.clientHeight ? 
          document.documentElement.clientHeight : document.body.clientHeight);
    this.scrollStart = Position.deltaY;
    this.delta  = (offsets[1] > max ? max : offsets[1]) - this.scrollStart;
    this.start(arguments[1] || {});
  },
  update: function(position) {
    Position.prepare();
    window.scrollTo(Position.deltaX, 
      this.scrollStart + (position*this.delta));
  }
});

/* ------------- prepackaged effects ------------- */

Effect.Fade = function(element) {
  options = Object.extend({
  from: 1.0,
  to:   0.0,
  afterFinish: function(effect) 
    { Element.hide(effect.element);
      effect.setOpacity(1); } 
  }, arguments[1] || {});
  new Effect.Opacity(element,options);
}

Effect.Appear = function(element) {
  options = Object.extend({
  from: 0.0,
  to:   1.0,
  beforeStart: function(effect)  
    { effect.setOpacity(0);
      Element.show(effect.element); },
  afterUpdate: function(effect)  
    { Element.show(effect.element); }
  }, arguments[1] || {});
  new Effect.Opacity(element,options);
}

Effect.Puff = function(element) {
  new Effect.Parallel(
   [ new Effect.Scale(element, 200, { sync: true, scaleFromCenter: true }), 
     new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0 } ) ], 
     { duration: 1.0, 
      afterUpdate: function(effect) 
       { effect.effects[0].element.style.position = 'absolute'; },
      afterFinish: function(effect)
       { Element.hide(effect.effects[0].element); }
     }
   );
}

Effect.BlindUp = function(element) {
  Element.makeClipping(element);
  new Effect.Scale(element, 0, 
    Object.extend({ scaleContent: false, 
      scaleX: false, 
      afterFinish: function(effect) 
        { 
          Element.hide(effect.element);
          Element.undoClipping(effect.element);
        } 
    }, arguments[1] || {})
  );
}

Effect.BlindDown = function(element) {
  $(element).style.height   = '0px';
  Element.makeClipping(element);
  Element.show(element);
  new Effect.Scale(element, 100, 
    Object.extend({ scaleContent: false, 
      scaleX: false, 
      scaleMode: 'contents',
      scaleFrom: 0,
      afterFinish: function(effect) {
        Element.undoClipping(effect.element);
      }
    }, arguments[1] || {})
  );
}

Effect.SwitchOff = function(element) {
  new Effect.Appear(element,
    { duration: 0.4,
     transition: Effect.Transitions.flicker,
     afterFinish: function(effect)
      { effect.element.style.overflow = 'hidden';
        new Effect.Scale(effect.element, 1, 
         { duration: 0.3, scaleFromCenter: true,
          scaleX: false, scaleContent: false,
          afterUpdate: function(effect) { 
           if(effect.element.style.position=="")
             effect.element.style.position = 'relative'; },
          afterFinish: function(effect) { Element.hide(effect.element); }
         } )
      }
    } );
}

Effect.DropOut = function(element) {
  new Effect.Parallel(
    [ new Effect.MoveBy(element, 100, 0, { sync: true }), 
      new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0 } ) ], 
    { duration: 0.5, 
     afterFinish: function(effect)
       { Element.hide(effect.effects[0].element); } 
    });
}

Effect.Shake = function(element) {
  new Effect.MoveBy(element, 0, 20, 
    { duration: 0.05, afterFinish: function(effect) {
  new Effect.MoveBy(effect.element, 0, -40, 
    { duration: 0.1, afterFinish: function(effect) { 
  new Effect.MoveBy(effect.element, 0, 40, 
    { duration: 0.1, afterFinish: function(effect) {  
  new Effect.MoveBy(effect.element, 0, -40, 
    { duration: 0.1, afterFinish: function(effect) {  
  new Effect.MoveBy(effect.element, 0, 40, 
    { duration: 0.1, afterFinish: function(effect) {  
  new Effect.MoveBy(effect.element, 0, -20, 
    { duration: 0.05, afterFinish: function(effect) {  
  }}) }}) }}) }}) }}) }});
}

Effect.SlideDown = function(element) {
  element = $(element);
  element.style.height   = '0px';
  Element.makeClipping(element);
  Element.cleanWhitespace(element);
  Element.makePositioned(element.firstChild);
  Element.show(element);
  new Effect.Scale(element, 100, 
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    scaleMode: 'contents',
    scaleFrom: 0,
    afterUpdate: function(effect) 
      { effect.element.firstChild.style.bottom = 
          (effect.originalHeight - effect.element.clientHeight) + 'px'; },
    afterFinish: function(effect) 
      {  Element.undoClipping(effect.element); }
    }, arguments[1] || {})
  );
}
  
Effect.SlideUp = function(element) {
  element = $(element);
  Element.makeClipping(element);
  Element.cleanWhitespace(element);
  Element.makePositioned(element.firstChild);
  Element.show(element);
  new Effect.Scale(element, 0, 
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    afterUpdate: function(effect) 
      { effect.element.firstChild.style.bottom = 
          (effect.originalHeight - effect.element.clientHeight) + 'px'; },
    afterFinish: function(effect)
      { 
        Element.hide(effect.element);
        Element.undoClipping(effect.element);
      }
   }, arguments[1] || {})
  );
}

Effect.Squish = function(element) {
 new Effect.Scale(element, 0, 
   { afterFinish: function(effect) { Element.hide(effect.element); } });
}

Effect.Grow = function(element) {
  element = $(element);
  var options = arguments[1] || {};
  
  var originalWidth = element.clientWidth;
  var originalHeight = element.clientHeight;
  element.style.overflow = 'hidden';
  Element.show(element);
  
  var direction = options.direction || 'center';
  var moveTransition = options.moveTransition || Effect.Transitions.sinoidal;
  var scaleTransition = options.scaleTransition || Effect.Transitions.sinoidal;
  var opacityTransition = options.opacityTransition || Effect.Transitions.full;
  
  var initialMoveX, initialMoveY;
  var moveX, moveY;
  
  switch (direction) {
    case 'top-left':
      initialMoveX = initialMoveY = moveX = moveY = 0; 
      break;
    case 'top-right':
      initialMoveX = originalWidth;
      initialMoveY = moveY = 0;
      moveX = -originalWidth;
      break;
    case 'bottom-left':
      initialMoveX = moveX = 0;
      initialMoveY = originalHeight;
      moveY = -originalHeight;
      break;
    case 'bottom-right':
      initialMoveX = originalWidth;
      initialMoveY = originalHeight;
      moveX = -originalWidth;
      moveY = -originalHeight;
      break;
    case 'center':
      initialMoveX = originalWidth / 2;
      initialMoveY = originalHeight / 2;
      moveX = -originalWidth / 2;
      moveY = -originalHeight / 2;
      break;
  }
  
  new Effect.MoveBy(element, initialMoveY, initialMoveX, { 
    duration: 0.01, 
    beforeUpdate: function(effect) { $(element).style.height = '0px'; },
    afterFinish: function(effect) {
      new Effect.Parallel(
        [ new Effect.Opacity(element, { sync: true, to: 1.0, from: 0.0, transition: opacityTransition }),
          new Effect.MoveBy(element, moveY, moveX, { sync: true, transition: moveTransition }),
          new Effect.Scale(element, 100, { 
            scaleMode: { originalHeight: originalHeight, originalWidth: originalWidth }, 
            sync: true, scaleFrom: 0, scaleTo: 100, transition: scaleTransition })],
        options); }
    });
}

Effect.Shrink = function(element) {
  element = $(element);
  var options = arguments[1] || {};
  
  var originalWidth = element.clientWidth;
  var originalHeight = element.clientHeight;
  element.style.overflow = 'hidden';
  Element.show(element);

  var direction = options.direction || 'center';
  var moveTransition = options.moveTransition || Effect.Transitions.sinoidal;
  var scaleTransition = options.scaleTransition || Effect.Transitions.sinoidal;
  var opacityTransition = options.opacityTransition || Effect.Transitions.none;
  
  var moveX, moveY;
  
  switch (direction) {
    case 'top-left':
      moveX = moveY = 0;
      break;
    case 'top-right':
      moveX = originalWidth;
      moveY = 0;
      break;
    case 'bottom-left':
      moveX = 0;
      moveY = originalHeight;
      break;
    case 'bottom-right':
      moveX = originalWidth;
      moveY = originalHeight;
      break;
    case 'center':  
      moveX = originalWidth / 2;
      moveY = originalHeight / 2;
      break;
  }
  
  new Effect.Parallel(
    [ new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0, transition: opacityTransition }),
      new Effect.Scale(element, 0, { sync: true, transition: moveTransition }),
      new Effect.MoveBy(element, moveY, moveX, { sync: true, transition: scaleTransition }) ],
    options);
}

Effect.Pulsate = function(element) {
  var options    = arguments[1] || {};
  var transition = options.transition || Effect.Transitions.sinoidal;
  var reverser   = function(pos){ return transition(1-Effect.Transitions.pulse(pos)) };
  reverser.bind(transition);
  new Effect.Opacity(element, 
    Object.extend(Object.extend({  duration: 3.0,
       afterFinish: function(effect) { Element.show(effect.element); }
    }, options), {transition: reverser}));
}

Effect.Fold = function(element) {
 $(element).style.overflow = 'hidden';
 new Effect.Scale(element, 5, Object.extend({   
   scaleContent: false,
   scaleTo: 100,
   scaleX: false,
   afterFinish: function(effect) {
   new Effect.Scale(element, 1, { 
     scaleContent: false, 
     scaleTo: 0,
     scaleY: false,
     afterFinish: function(effect) { Element.hide(effect.element) } });
 }}, arguments[1] || {}));
}

// old: new Effect.ContentZoom(element, percent)
// new: Element.setContentZoom(element, percent) 

Element.setContentZoom = function(element, percent) {
  var element = $(element);
  element.style.fontSize = (percent/100) + "em";  
  if(navigator.appVersion.indexOf('AppleWebKit')>0) window.scrollBy(0,0);
}
