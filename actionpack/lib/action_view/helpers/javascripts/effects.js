// Copyright (c) 2005 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
// Contributors:
//  Justin Palmer (http://encytemedia.com/)
//  Mark Pilgrim (http://diveintomark.org/)
//  Martin Bialasinki
// 
// See scriptaculous.js for full license.  

/* ------------- element ext -------------- */  
 
// converts rgb() and #xxx to #xxxxxx format,  
// returns self (or first argument) if not convertable  
String.prototype.parseColor = function() {  
  color = "#";  
  if(this.slice(0,4) == "rgb(") {  
    var cols = this.slice(4,this.length-1).split(',');  
    var i=0; do { color += parseInt(cols[i]).toColorPart() } while (++i<3);  
  } else {  
    if(this.slice(0,1) == '#') {  
      if(this.length==4) for(var i=1;i<4;i++) color += (this.charAt(i) + this.charAt(i)).toLowerCase();  
      if(this.length==7) color = this.toLowerCase();  
    }  
  }  
  return(color.length==7 ? color : (arguments[0] || this));  
}  

Element.collectTextNodesIgnoreClass = function(element, ignoreclass) {  
  var children = $(element).childNodes;  
  var text     = "";  
  var classtest = new RegExp("^([^ ]+ )*" + ignoreclass+ "( [^ ]+)*$","i");  
 
  for (var i = 0; i < children.length; i++) {  
    if(children[i].nodeType==3) {  
      text+=children[i].nodeValue;  
    } else {  
      if((!children[i].className.match(classtest)) && children[i].hasChildNodes())  
        text += Element.collectTextNodesIgnoreClass(children[i], ignoreclass);  
    }  
  }  
 
  return text;
}

Element.setContentZoom = function(element, percent) {  
  element = $(element);  
  element.style.fontSize = (percent/100) + "em";   
  if(navigator.appVersion.indexOf('AppleWebKit')>0) window.scrollBy(0,0);  
}

Element.getOpacity = function(element){  
  var opacity;  
  if (opacity = Element.getStyle(element, "opacity"))  
    return parseFloat(opacity);  
  if (opacity = (Element.getStyle(element, "filter") || '').match(/alpha\(opacity=(.*)\)/))  
    if(opacity[1]) return parseFloat(opacity[1]) / 100;  
  return 1.0;  
}

Element.setOpacity = function(element, value){  
  element= $(element);  
  var els = element.style;  
  if (value == 1){  
    els.opacity = '0.999999';  
    if(/MSIE/.test(navigator.userAgent))  
      els.filter = Element.getStyle(element,'filter').replace(/alpha\([^\)]*\)/gi,'');  
  } else {  
    if(value < 0.00001) value = 0;  
    els.opacity = value;  
    if(/MSIE/.test(navigator.userAgent))  
      els.filter = Element.getStyle(element,'filter').replace(/alpha\([^\)]*\)/gi,'') +  
        "alpha(opacity="+value*100+")";  
  }   
}  
 
Element.getInlineOpacity = function(element){  
  element= $(element);  
  var op;  
  op = element.style.opacity;  
  if (typeof op != "undefined" && op != "") return op;  
  return "";  
}  
 
Element.setInlineOpacity = function(element, value){  
  element= $(element);  
  var els = element.style;  
  els.opacity = value;  
}  
 
Element.childrenWithClassName = function(element, className) {  
  return $A($(element).getElementsByTagName('*')).select(
    function(c) { return Element.hasClassName(c, className) });
}  
 
/*--------------------------------------------------------------------------*/

var Effect = {
  tagifyText: function(element) {
    var tagifyStyle = "position:relative";
    if(/MSIE/.test(navigator.userAgent)) tagifyStyle += ";zoom:1";
    element = $(element);
    $A(element.childNodes).each( function(child) {
      if(child.nodeType==3) {
        child.nodeValue.toArray().each( function(character) {
          element.insertBefore(
            Builder.node('span',{style: tagifyStyle},
              character == " " ? String.fromCharCode(160) : character), 
              child);
        });
        Element.remove(child);
      }
    });
  },
  multiple: function(element, effect) {
    var elements;
    if(((typeof element == 'object') || 
        (typeof element == 'function')) && 
       (element.length))
      elements = element;
    else
      elements = $(element).childNodes;
      
    var options = Object.extend({
      speed: 0.1,
      delay: 0.0
    }, arguments[2] || {});
    var speed = options.speed;
    var delay = options.delay;

    $A(elements).each( function(element, index) {
      new effect(element, Object.extend(options, { delay: delay + index * speed }));
    });
  }
};

var Effect2 = Effect; // deprecated

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
  return ((-Math.cos(pos*Math.PI)/4) + 0.75) + Math.random()/4;
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

/* ------------- core effects ------------- */

Effect.Queue = {
  effects:  [],
  _each: function(iterator) {
    this.effects._each(iterator);
  },
  interval: null,
  add: function(effect) {
    var timestamp = new Date().getTime();
    
    switch(effect.options.queue) {
      case 'front':
        // move unstarted effects after this effect  
        this.effects.findAll(function(e){ return e.state=='idle' }).each( function(e) {
            e.startOn  += effect.finishOn;
            e.finishOn += effect.finishOn;
          });
        break;
      case 'end':
        // start effect after last queued effect has finished
        timestamp = this.effects.pluck('finishOn').max() || timestamp;
        break;
    }
    
    effect.startOn  += timestamp;
    effect.finishOn += timestamp;
    this.effects.push(effect);
    if(!this.interval) 
      this.interval = setInterval(this.loop.bind(this), 40);
  },
  remove: function(effect) {
    this.effects = this.effects.reject(function(e) { return e==effect });
    if(this.effects.length == 0) {
      clearInterval(this.interval);
      this.interval = null;
    }
  },
  loop: function() {
    var timePos = new Date().getTime();
    this.effects.invoke('loop', timePos);
  }
}
Object.extend(Effect.Queue, Enumerable);

Effect.Base = function() {};
Effect.Base.prototype = {
  position: null,
  setOptions: function(options) {
    this.options = Object.extend({
      transition: Effect.Transitions.sinoidal,
      duration:   1.0,   // seconds
      fps:        25.0,  // max. 25fps due to Effect.Queue implementation
      sync:       false, // true for combining
      from:       0.0,
      to:         1.0,
      delay:      0.0,
      queue:      'parallel'
    }, options || {});
  },
  start: function(options) {
    this.setOptions(options || {});
    this.currentFrame = 0;
    this.state        = 'idle';
    this.startOn      = this.options.delay*1000;
    this.finishOn     = this.startOn + (this.options.duration*1000);
    this.event('beforeStart');
    if(!this.options.sync) Effect.Queue.add(this);
  },
  loop: function(timePos) {
    if(timePos >= this.startOn) {
      if(timePos >= this.finishOn) {
        this.render(1.0);
        this.cancel();
        this.event('beforeFinish');
        if(this.finish) this.finish(); 
        this.event('afterFinish');
        return;  
      }
      var pos   = (timePos - this.startOn) / (this.finishOn - this.startOn);
      var frame = Math.round(pos * this.options.fps * this.options.duration);
      if(frame > this.currentFrame) {
        this.render(pos);
        this.currentFrame = frame;
      }
    }
  },
  render: function(pos) {
    if(this.state == 'idle') {
      this.state = 'running';
      this.event('beforeSetup');
      if(this.setup) this.setup();
      this.event('afterSetup');
    }
    if(this.options.transition) pos = this.options.transition(pos);
    pos *= (this.options.to-this.options.from);
    pos += this.options.from;
    this.position = pos;
    this.event('beforeUpdate');
    if(this.update) this.update(pos);
    this.event('afterUpdate');
  },
  cancel: function() {
    if(!this.options.sync) Effect.Queue.remove(this);
    this.state = 'finished';
  },
  event: function(eventName) {
    if(this.options[eventName + 'Internal']) this.options[eventName + 'Internal'](this);
    if(this.options[eventName]) this.options[eventName](this);
  }
}

Effect.Parallel = Class.create();
Object.extend(Object.extend(Effect.Parallel.prototype, Effect.Base.prototype), {
  initialize: function(effects) {
    this.effects = effects || [];
    this.start(arguments[1]);
  },
  update: function(position) {
    this.effects.invoke('render', position);
  },
  finish: function(position) {
    this.effects.each( function(effect) {
      effect.render(1.0);
      effect.cancel();
      effect.event('beforeFinish');
      if(effect.finish) effect.finish(position);
      effect.event('afterFinish');
    });
  }
});

Effect.Opacity = Class.create();
Object.extend(Object.extend(Effect.Opacity.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    // make this work on IE on elements without 'layout'
    if(/MSIE/.test(navigator.userAgent) && (!this.element.hasLayout))
      this.element.style.zoom = 1;
    var options = Object.extend({
      from: Element.getOpacity(this.element) || 0.0,
      to:   1.0
    }, arguments[1] || {});
    this.start(options);
  },
  update: function(position) {
    Element.setOpacity(this.element, position);
  }
});

Effect.MoveBy = Class.create();
Object.extend(Object.extend(Effect.MoveBy.prototype, Effect.Base.prototype), {
  initialize: function(element, toTop, toLeft) {
    this.element      = $(element);
    this.toTop        = toTop;
    this.toLeft       = toLeft;
    this.start(arguments[3]);
  },
  setup: function() {
    // Bug in Opera: Opera returns the "real" position of a static element or
    // relative element that does not have top/left explicitly set.
    // ==> Always set top and left for position relative elements in your stylesheets 
    // (to 0 if you do not need them)
    
    Element.makePositioned(this.element);
    this.originalTop  = parseFloat(Element.getStyle(this.element,'top')  || '0');
    this.originalLeft = parseFloat(Element.getStyle(this.element,'left') || '0');
  },
  update: function(position) {
    var topd  = this.toTop  * position + this.originalTop;
    var leftd = this.toLeft * position + this.originalLeft;
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
    var options = Object.extend({
      scaleX: true,
      scaleY: true,
      scaleContent: true,
      scaleFromCenter: false,
      scaleMode: 'box',        // 'box' or 'contents' or {} with provided values
      scaleFrom: 100.0,
      scaleTo:   percent
    }, arguments[2] || {});
    this.start(options);
  },
  setup: function() {
    var effect = this;
    
    this.restoreAfterFinish = this.options.restoreAfterFinish || false;
    this.elementPositioning = Element.getStyle(this.element,'position');
    
    effect.originalStyle = {};
    ['top','left','width','height','fontSize'].each( function(k) {
      effect.originalStyle[k] = effect.element.style[k];
    });
      
    this.originalTop  = this.element.offsetTop;
    this.originalLeft = this.element.offsetLeft;
    
    var fontSize = Element.getStyle(this.element,'font-size') || "100%";
    ['em','px','%'].each( function(fontSizeType) {
      if(fontSize.indexOf(fontSizeType)>0) {
        effect.fontSize     = parseFloat(fontSize);
        effect.fontSizeType = fontSizeType;
      }
    });
    
    this.factor = (this.options.scaleTo - this.options.scaleFrom)/100;
    
    this.dims = null;
    if(this.options.scaleMode=='box')
      this.dims = [this.element.clientHeight, this.element.clientWidth];
    if(this.options.scaleMode=='content')
      this.dims = [this.element.scrollHeight, this.element.scrollWidth];
    if(!this.dims)
      this.dims = [this.options.scaleMode.originalHeight,
                   this.options.scaleMode.originalWidth];
  },
  update: function(position) {
    var currentScale = (this.options.scaleFrom/100.0) + (this.factor * position);
    if(this.options.scaleContent && this.fontSize)
      this.element.style.fontSize = this.fontSize*currentScale + this.fontSizeType;
    this.setDimensions(this.dims[0] * currentScale, this.dims[1] * currentScale);
  },
  finish: function(position) {
    if (this.restoreAfterFinish) {
      var effect = this;
      ['top','left','width','height','fontSize'].each( function(k) {
        effect.element.style[k] = effect.originalStyle[k];
      });
    }
  },
  setDimensions: function(height, width) {
    var els = this.element.style;
    if(this.options.scaleX) els.width = width + 'px';
    if(this.options.scaleY) els.height = height + 'px';
    if(this.options.scaleFromCenter) {
      var topd  = (height - this.dims[0])/2;
      var leftd = (width  - this.dims[1])/2;
      if(this.elementPositioning == 'absolute') {
        if(this.options.scaleY) els.top = this.originalTop-topd + "px";
        if(this.options.scaleX) els.left = this.originalLeft-leftd + "px";
      } else {
        if(this.options.scaleY) els.top = -topd + "px";
        if(this.options.scaleX) els.left = -leftd + "px";
      }
    }
  }
});

Effect.Highlight = Class.create();
Object.extend(Object.extend(Effect.Highlight.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    var options = Object.extend({
      startcolor:   "#ffff99"
    }, arguments[1] || {});
    this.start(options);
  },
  setup: function() {
    // Prevent executing on elements not in the layout flow
    if(this.element.style.display=='none') { this.cancel(); return; }
    // Disable background image during the effect
    this.oldBgImage = this.element.style.backgroundImage;
    this.element.style.backgroundImage = "none";
    if(!this.options.endcolor)
      this.options.endcolor = Element.getStyle(this.element, 'background-color').parseColor('#ffffff');
    if (typeof this.options.restorecolor == "undefined")
      this.options.restorecolor = this.element.style.backgroundColor;
    // init color calculations
    this.colors_base = [
      parseInt(this.options.startcolor.slice(1,3),16),
      parseInt(this.options.startcolor.slice(3,5),16),
      parseInt(this.options.startcolor.slice(5),16) ];
    this.colors_delta = [
      parseInt(this.options.endcolor.slice(1,3),16)-this.colors_base[0],
      parseInt(this.options.endcolor.slice(3,5),16)-this.colors_base[1],
      parseInt(this.options.endcolor.slice(5),16)-this.colors_base[2]];
  },
  update: function(position) {
    var effect = this; var colors = $R(0,2).map( function(i){ 
      return Math.round(effect.colors_base[i]+(effect.colors_delta[i]*position))
    });
    this.element.style.backgroundColor = "#" +
      colors[0].toColorPart() + colors[1].toColorPart() + colors[2].toColorPart();
  },
  finish: function() {
    this.element.style.backgroundColor = this.options.restorecolor;
    this.element.style.backgroundImage = this.oldBgImage;
  }
});

Effect.ScrollTo = Class.create();
Object.extend(Object.extend(Effect.ScrollTo.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    this.start(arguments[1] || {});
  },
  setup: function() {
    Position.prepare();
    var offsets = Position.cumulativeOffset(this.element);
    var max = window.innerHeight ? 
      window.height - window.innerHeight :
      document.body.scrollHeight - 
        (document.documentElement.clientHeight ? 
          document.documentElement.clientHeight : document.body.clientHeight);
    this.scrollStart = Position.deltaY;
    this.delta = (offsets[1] > max ? max : offsets[1]) - this.scrollStart;
  },
  update: function(position) {
    Position.prepare();
    window.scrollTo(Position.deltaX, 
      this.scrollStart + (position*this.delta));
  }
});

/* ------------- combination effects ------------- */

Effect.Fade = function(element) {
  var oldOpacity = Element.getInlineOpacity(element);
  var options = Object.extend({
  from: Element.getOpacity(element) || 1.0,
  to:   0.0,
  afterFinishInternal: function(effect) 
    { if (effect.options.to == 0) {
        Element.hide(effect.element);
        Element.setInlineOpacity(effect.element, oldOpacity);
      }  
    }
  }, arguments[1] || {});
  return new Effect.Opacity(element,options);
}

Effect.Appear = function(element) {
  var options = Object.extend({
  from: (Element.getStyle(element, "display") == "none" ? 0.0 : Element.getOpacity(element) || 0.0),
  to:   1.0,
  beforeSetup: function(effect)  
    { Element.setOpacity(effect.element, effect.options.from);
      Element.show(effect.element); }
  }, arguments[1] || {});
  return new Effect.Opacity(element,options);
}

Effect.Puff = function(element) {
  element = $(element);
  var oldOpacity = Element.getInlineOpacity(element);
  var oldPosition = element.style.position;
  return new Effect.Parallel(
   [ new Effect.Scale(element, 200, 
      { sync: true, scaleFromCenter: true, scaleContent: true, restoreAfterFinish: true }), 
     new Effect.Opacity(element, { sync: true, to: 0.0 } ) ], 
     Object.extend({ duration: 1.0, 
      beforeSetupInternal: function(effect) 
       { effect.effects[0].element.style.position = 'absolute'; },
      afterFinishInternal: function(effect)
       { Element.hide(effect.effects[0].element);
         effect.effects[0].element.style.position = oldPosition;
         Element.setInlineOpacity(effect.effects[0].element, oldOpacity); }
     }, arguments[1] || {})
   );
}

Effect.BlindUp = function(element) {
  element = $(element);
  Element.makeClipping(element);
  return new Effect.Scale(element, 0, 
    Object.extend({ scaleContent: false, 
      scaleX: false, 
      restoreAfterFinish: true,
      afterFinishInternal: function(effect)
        { 
          Element.hide(effect.element);
          Element.undoClipping(effect.element);
        } 
    }, arguments[1] || {})
  );
}

Effect.BlindDown = function(element) {
  element = $(element);
  var oldHeight = element.style.height;
  var elementDimensions = Element.getDimensions(element);
  return new Effect.Scale(element, 100, 
    Object.extend({ scaleContent: false, 
      scaleX: false,
      scaleFrom: 0,
      scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
      restoreAfterFinish: true,
      afterSetup: function(effect) {
        Element.makeClipping(effect.element);
        effect.element.style.height = "0px";
        Element.show(effect.element); 
      },  
      afterFinishInternal: function(effect) {
        Element.undoClipping(effect.element);
        effect.element.style.height = oldHeight;
      }
    }, arguments[1] || {})
  );
}

Effect.SwitchOff = function(element) {
  element = $(element);
  var oldOpacity = Element.getInlineOpacity(element);
  return new Effect.Appear(element, { 
    duration: 0.4,
    from: 0,
    transition: Effect.Transitions.flicker,
    afterFinishInternal: function(effect) {
      new Effect.Scale(effect.element, 1, { 
        duration: 0.3, scaleFromCenter: true,
        scaleX: false, scaleContent: false, restoreAfterFinish: true,
        beforeSetup: function(effect) { 
          Element.makePositioned(effect.element); 
          Element.makeClipping(effect.element);
        },
        afterFinishInternal: function(effect) { 
          Element.hide(effect.element); 
          Element.undoClipping(effect.element);
          Element.undoPositioned(effect.element);
          Element.setInlineOpacity(effect.element, oldOpacity);
        }
      })
    }
  });
}

Effect.DropOut = function(element) {
  element = $(element);
  var oldTop = element.style.top;
  var oldLeft = element.style.left;
  var oldOpacity = Element.getInlineOpacity(element);
  return new Effect.Parallel(
    [ new Effect.MoveBy(element, 100, 0, { sync: true }), 
      new Effect.Opacity(element, { sync: true, to: 0.0 }) ],
    Object.extend(
      { duration: 0.5,
        beforeSetup: function(effect) { 
          Element.makePositioned(effect.effects[0].element); },
        afterFinishInternal: function(effect) { 
          Element.hide(effect.effects[0].element); 
          Element.undoPositioned(effect.effects[0].element);
          effect.effects[0].element.style.left = oldLeft;
          effect.effects[0].element.style.top = oldTop;
          Element.setInlineOpacity(effect.effects[0].element, oldOpacity); } 
      }, arguments[1] || {}));
}

Effect.Shake = function(element) {
  element = $(element);
  var oldTop = element.style.top;
  var oldLeft = element.style.left;
  return new Effect.MoveBy(element, 0, 20, 
    { duration: 0.05, afterFinishInternal: function(effect) {
  new Effect.MoveBy(effect.element, 0, -40, 
    { duration: 0.1, afterFinishInternal: function(effect) {
  new Effect.MoveBy(effect.element, 0, 40, 
    { duration: 0.1, afterFinishInternal: function(effect) {
  new Effect.MoveBy(effect.element, 0, -40, 
    { duration: 0.1, afterFinishInternal: function(effect) {
  new Effect.MoveBy(effect.element, 0, 40, 
    { duration: 0.1, afterFinishInternal: function(effect) {
  new Effect.MoveBy(effect.element, 0, -20, 
    { duration: 0.05, afterFinishInternal: function(effect) {
        Element.undoPositioned(effect.element);
        effect.element.style.left = oldLeft;
        effect.element.style.top = oldTop;
  }}) }}) }}) }}) }}) }});
}

Effect.SlideDown = function(element) {
  element = $(element);
  Element.cleanWhitespace(element);
  // SlideDown need to have the content of the element wrapped in a container element with fixed height!
  var oldInnerBottom = element.firstChild.style.bottom;
  var elementDimensions = Element.getDimensions(element);
  return new Effect.Scale(element, 100, 
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    scaleFrom: 0,
    scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},    
    restoreAfterFinish: true,
    afterSetup: function(effect) {
      Element.makePositioned(effect.element.firstChild);
      if (window.opera) effect.element.firstChild.style.top = "";
      Element.makeClipping(effect.element);
      element.style.height = '0';
      Element.show(element); 
    },  
    afterUpdateInternal: function(effect) { 
      effect.element.firstChild.style.bottom = 
        (effect.dims[0] - effect.element.clientHeight) + 'px'; },
    afterFinishInternal: function(effect) { 
      Element.undoClipping(effect.element); 
      Element.undoPositioned(effect.element.firstChild);
      effect.element.firstChild.style.bottom = oldInnerBottom; }
    }, arguments[1] || {})
  );
}
  
Effect.SlideUp = function(element) {
  element = $(element);
  Element.cleanWhitespace(element);
  var oldInnerBottom = element.firstChild.style.bottom;
  return new Effect.Scale(element, 0, 
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    scaleMode: 'box',
    scaleFrom: 100,
    restoreAfterFinish: true,
    beforeStartInternal: function(effect) { 
      Element.makePositioned(effect.element.firstChild);
      if (window.opera) effect.element.firstChild.style.top = "";
      Element.makeClipping(effect.element);
      Element.show(element); 
    },  
    afterUpdateInternal: function(effect) { 
     effect.element.firstChild.style.bottom = 
       (effect.dims[0] - effect.element.clientHeight) + 'px'; },
    afterFinishInternal: function(effect) { 
        Element.hide(effect.element);
        Element.undoClipping(effect.element); 
        Element.undoPositioned(effect.element.firstChild);
        effect.element.firstChild.style.bottom = oldInnerBottom; }
   }, arguments[1] || {})
  );
}

Effect.Squish = function(element) {
  // Bug in opera makes the TD containing this element expand for a instance after finish 
  return new Effect.Scale(element, window.opera ? 1 : 0, 
    { restoreAfterFinish: true,
      beforeSetup: function(effect) { 
        Element.makeClipping(effect.element); },  
      afterFinishInternal: function(effect) { 
        Element.hide(effect.element); 
        Element.undoClipping(effect.element); } 
  });
}

Effect.Grow = function(element) {
  element = $(element);
  var options = arguments[1] || {};
  
  var elementDimensions = Element.getDimensions(element);
  var originalWidth = elementDimensions.width;
  var originalHeight = elementDimensions.height;
  var oldTop = element.style.top;
  var oldLeft = element.style.left;
  var oldHeight = element.style.height;
  var oldWidth = element.style.width;
  var oldOpacity = Element.getInlineOpacity(element);
  
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
  
  return new Effect.MoveBy(element, initialMoveY, initialMoveX, { 
    duration: 0.01, 
    beforeSetup: function(effect) { 
      Element.hide(effect.element);
      Element.makeClipping(effect.element);
      Element.makePositioned(effect.element);
    },
    afterFinishInternal: function(effect) {
      new Effect.Parallel(
        [ new Effect.Opacity(effect.element, { sync: true, to: 1.0, from: 0.0, transition: opacityTransition }),
          new Effect.MoveBy(effect.element, moveY, moveX, { sync: true, transition: moveTransition }),
          new Effect.Scale(effect.element, 100, {
            scaleMode: { originalHeight: originalHeight, originalWidth: originalWidth }, 
            sync: true, scaleFrom: window.opera ? 1 : 0, transition: scaleTransition, restoreAfterFinish: true})
        ], Object.extend({
             beforeSetup: function(effect) {
              effect.effects[0].element.style.height = 0;
              Element.show(effect.effects[0].element);
             },              
             afterFinishInternal: function(effect) {
               var el = effect.effects[0].element;
               var els = el.style;
               Element.undoClipping(el); 
               Element.undoPositioned(el);
               els.top = oldTop;
               els.left = oldLeft;
               els.height = oldHeight;
               els.width = originalWidth + 'px';
               Element.setInlineOpacity(el, oldOpacity);
             }
           }, options)
      )
    }
  });
}

Effect.Shrink = function(element) {
  element = $(element);
  var options = arguments[1] || {};
  
  var originalWidth = element.clientWidth;
  var originalHeight = element.clientHeight;
  var oldTop = element.style.top;
  var oldLeft = element.style.left;
  var oldHeight = element.style.height;
  var oldWidth = element.style.width;
  var oldOpacity = Element.getInlineOpacity(element);

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
  
  return new Effect.Parallel(
    [ new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0, transition: opacityTransition }),
      new Effect.Scale(element, window.opera ? 1 : 0, { sync: true, transition: scaleTransition, restoreAfterFinish: true}),
      new Effect.MoveBy(element, moveY, moveX, { sync: true, transition: moveTransition })
    ], Object.extend({            
         beforeStartInternal: function(effect) { 
           Element.makePositioned(effect.effects[0].element);
           Element.makeClipping(effect.effects[0].element);
         },
         afterFinishInternal: function(effect) {
           var el = effect.effects[0].element;
           var els = el.style;
           Element.hide(el);
           Element.undoClipping(el); 
           Element.undoPositioned(el);
           els.top = oldTop;
           els.left = oldLeft;
           els.height = oldHeight;
           els.width = oldWidth;
           Element.setInlineOpacity(el, oldOpacity);
         }
       }, options)
  );
}

Effect.Pulsate = function(element) {
  element = $(element);
  var options    = arguments[1] || {};
  var oldOpacity = Element.getInlineOpacity(element);
  var transition = options.transition || Effect.Transitions.sinoidal;
  var reverser   = function(pos){ return transition(1-Effect.Transitions.pulse(pos)) };
  reverser.bind(transition);
  return new Effect.Opacity(element, 
    Object.extend(Object.extend({  duration: 3.0, from: 0,
      afterFinishInternal: function(effect) { Element.setInlineOpacity(effect.element, oldOpacity); }
    }, options), {transition: reverser}));
}

Effect.Fold = function(element) {
  element = $(element);
  var originalTop = element.style.top;
  var originalLeft = element.style.left;
  var originalWidth = element.style.width;
  var originalHeight = element.style.height;
  Element.makeClipping(element);
  return new Effect.Scale(element, 5, Object.extend({   
    scaleContent: false,
    scaleX: false,
    afterFinishInternal: function(effect) {
    new Effect.Scale(element, 1, { 
      scaleContent: false, 
      scaleY: false,
      afterFinishInternal: function(effect) { 
        Element.hide(effect.element);  
        Element.undoClipping(effect.element); 
        effect.element.style.top = originalTop;
        effect.element.style.left = originalLeft;
        effect.element.style.width = originalWidth;
        effect.element.style.height = originalHeight;
      } });
  }}, arguments[1] || {}));
}
