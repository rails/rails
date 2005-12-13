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
  var color = '#';  
  if(this.slice(0,4) == 'rgb(') {  
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
  var text     = '';  
  var classtest = new RegExp('^([^ ]+ )*' + ignoreclass+ '( [^ ]+)*$','i');  
 
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

Element.setStyle = function(element, style) {
  element = $(element);
  for(k in style) element.style[k.camelize()] = style[k];
}

Element.setContentZoom = function(element, percent) {  
  Element.setStyle(element, {fontSize: (percent/100) + 'em'});   
  if(navigator.appVersion.indexOf('AppleWebKit')>0) window.scrollBy(0,0);  
}

Element.getOpacity = function(element){  
  var opacity;
  if (opacity = Element.getStyle(element, 'opacity'))  
    return parseFloat(opacity);  
  if (opacity = (Element.getStyle(element, 'filter') || '').match(/alpha\(opacity=(.*)\)/))  
    if(opacity[1]) return parseFloat(opacity[1]) / 100;  
  return 1.0;  
}

Element.setOpacity = function(element, value){  
  element= $(element);  
  if (value == 1){
    Element.setStyle(element, { opacity: 
      (/Gecko/.test(navigator.userAgent) && !/Konqueror|Safari|KHTML/.test(navigator.userAgent)) ? 
      0.999999 : null });
    if(/MSIE/.test(navigator.userAgent))  
      Element.setStyle(element, {filter: Element.getStyle(element,'filter').replace(/alpha\([^\)]*\)/gi,'')});  
  } else {  
    if(value < 0.00001) value = 0;  
    Element.setStyle(element, {opacity: value});
    if(/MSIE/.test(navigator.userAgent))  
     Element.setStyle(element, 
       { filter: Element.getStyle(element,'filter').replace(/alpha\([^\)]*\)/gi,'') +
                 'alpha(opacity='+value*100+')' });  
  }   
}  
 
Element.getInlineOpacity = function(element){  
  return $(element).style.opacity || '';
}  

Element.childrenWithClassName = function(element, className) {  
  return $A($(element).getElementsByTagName('*')).select(
    function(c) { return Element.hasClassName(c, className) });
}

Array.prototype.call = function() {
  var args = arguments;
  this.each(function(f){ f.apply(this, args) });
}

/*--------------------------------------------------------------------------*/

var Effect = {
  tagifyText: function(element) {
    var tagifyStyle = 'position:relative';
    if(/MSIE/.test(navigator.userAgent)) tagifyStyle += ';zoom:1';
    element = $(element);
    $A(element.childNodes).each( function(child) {
      if(child.nodeType==3) {
        child.nodeValue.toArray().each( function(character) {
          element.insertBefore(
            Builder.node('span',{style: tagifyStyle},
              character == ' ' ? String.fromCharCode(160) : character), 
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
    var masterDelay = options.delay;

    $A(elements).each( function(element, index) {
      new effect(element, Object.extend(options, { delay: index * options.speed + masterDelay }));
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
    if(this.state == 'running') {
      if(this.options.transition) pos = this.options.transition(pos);
      pos *= (this.options.to-this.options.from);
      pos += this.options.from;
      this.position = pos;
      this.event('beforeUpdate');
      if(this.update) this.update(pos);
      this.event('afterUpdate');
    }
  },
  cancel: function() {
    if(!this.options.sync) Effect.Queue.remove(this);
    this.state = 'finished';
  },
  event: function(eventName) {
    if(this.options[eventName + 'Internal']) this.options[eventName + 'Internal'](this);
    if(this.options[eventName]) this.options[eventName](this);
  },
  inspect: function() {
    return '#<Effect:' + $H(this).inspect() + ',options:' + $H(this.options).inspect() + '>';
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
      Element.setStyle(this.element, {zoom: 1});
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
    Element.setStyle(this.element, {
      top:  this.toTop  * position + this.originalTop + 'px',
      left: this.toLeft * position + this.originalLeft + 'px'
    });
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
    this.restoreAfterFinish = this.options.restoreAfterFinish || false;
    this.elementPositioning = Element.getStyle(this.element,'position');
    
    this.originalStyle = {};
    ['top','left','width','height','fontSize'].each( function(k) {
      this.originalStyle[k] = this.element.style[k];
    }.bind(this));
      
    this.originalTop  = this.element.offsetTop;
    this.originalLeft = this.element.offsetLeft;
    
    var fontSize = Element.getStyle(this.element,'font-size') || '100%';
    ['em','px','%'].each( function(fontSizeType) {
      if(fontSize.indexOf(fontSizeType)>0) {
        this.fontSize     = parseFloat(fontSize);
        this.fontSizeType = fontSizeType;
      }
    }.bind(this));
    
    this.factor = (this.options.scaleTo - this.options.scaleFrom)/100;
    
    this.dims = null;
    if(this.options.scaleMode=='box')
      this.dims = [this.element.offsetHeight, this.element.offsetWidth];
    if(/^content/.test(this.options.scaleMode))
      this.dims = [this.element.scrollHeight, this.element.scrollWidth];
    if(!this.dims)
      this.dims = [this.options.scaleMode.originalHeight,
                   this.options.scaleMode.originalWidth];
  },
  update: function(position) {
    var currentScale = (this.options.scaleFrom/100.0) + (this.factor * position);
    if(this.options.scaleContent && this.fontSize)
      Element.setStyle(this.element, {fontSize: this.fontSize * currentScale + this.fontSizeType });
    this.setDimensions(this.dims[0] * currentScale, this.dims[1] * currentScale);
  },
  finish: function(position) {
    if (this.restoreAfterFinish) Element.setStyle(this.element, this.originalStyle);
  },
  setDimensions: function(height, width) {
    var d = {};
    if(this.options.scaleX) d.width = width + 'px';
    if(this.options.scaleY) d.height = height + 'px';
    if(this.options.scaleFromCenter) {
      var topd  = (height - this.dims[0])/2;
      var leftd = (width  - this.dims[1])/2;
      if(this.elementPositioning == 'absolute') {
        if(this.options.scaleY) d.top = this.originalTop-topd + 'px';
        if(this.options.scaleX) d.left = this.originalLeft-leftd + 'px';
      } else {
        if(this.options.scaleY) d.top = -topd + 'px';
        if(this.options.scaleX) d.left = -leftd + 'px';
      }
    }
    Element.setStyle(this.element, d);
  }
});

Effect.Highlight = Class.create();
Object.extend(Object.extend(Effect.Highlight.prototype, Effect.Base.prototype), {
  initialize: function(element) {
    this.element = $(element);
    var options = Object.extend({ startcolor: '#ffff99' }, arguments[1] || {});
    this.start(options);
  },
  setup: function() {
    // Prevent executing on elements not in the layout flow
    if(Element.getStyle(this.element, 'display')=='none') { this.cancel(); return; }
    // Disable background image during the effect
    this.oldStyle = {
      backgroundImage: Element.getStyle(this.element, 'background-image') };
    Element.setStyle(this.element, {backgroundImage: 'none'});
    if(!this.options.endcolor)
      this.options.endcolor = Element.getStyle(this.element, 'background-color').parseColor('#ffffff');
    if(!this.options.restorecolor)
      this.options.restorecolor = Element.getStyle(this.element, 'background-color');
    // init color calculations
    this._base  = $R(0,2).map(function(i){ return parseInt(this.options.startcolor.slice(i*2+1,i*2+3),16) }.bind(this));
    this._delta = $R(0,2).map(function(i){ return parseInt(this.options.endcolor.slice(i*2+1,i*2+3),16)-this._base[i] }.bind(this));
  },
  update: function(position) {
    Element.setStyle(this.element,{backgroundColor: $R(0,2).inject('#',function(m,v,i){
      return m+(Math.round(this._base[i]+(this._delta[i]*position)).toColorPart()); }.bind(this)) });
  },
  finish: function() {
    Element.setStyle(this.element, Object.extend(this.oldStyle, {
      backgroundColor: this.options.restorecolor
    }));
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
    if(this.options.offset) offsets[1] += this.options.offset;
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
  afterFinishInternal: function(effect) { with(Element) { 
    if(effect.options.to!=0) return;
    hide(effect.element);
    setStyle(effect.element, {opacity: oldOpacity}); }}
  }, arguments[1] || {});
  return new Effect.Opacity(element,options);
}

Effect.Appear = function(element) {
  var options = Object.extend({
  from: (Element.getStyle(element, 'display') == 'none' ? 0.0 : Element.getOpacity(element) || 0.0),
  to:   1.0,
  beforeSetup: function(effect) { with(Element) {
    setOpacity(effect.element, effect.options.from);
    show(effect.element); }}
  }, arguments[1] || {});
  return new Effect.Opacity(element,options);
}

Effect.Puff = function(element) {
  element = $(element);
  var oldStyle = { opacity: Element.getInlineOpacity(element), position: Element.getStyle(element, 'position') };
  return new Effect.Parallel(
   [ new Effect.Scale(element, 200, 
      { sync: true, scaleFromCenter: true, scaleContent: true, restoreAfterFinish: true }), 
     new Effect.Opacity(element, { sync: true, to: 0.0 } ) ], 
     Object.extend({ duration: 1.0, 
      beforeSetupInternal: function(effect) { with(Element) {
        setStyle(effect.effects[0].element, {position: 'absolute'}); }},
      afterFinishInternal: function(effect) { with(Element) {
         hide(effect.effects[0].element);
         setStyle(effect.effects[0].element, oldStyle); }}
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
      afterFinishInternal: function(effect) { with(Element) {
        [hide, undoClipping].call(effect.element); }} 
    }, arguments[1] || {})
  );
}

Effect.BlindDown = function(element) {
  element = $(element);
  var oldHeight = Element.getStyle(element, 'height');
  var elementDimensions = Element.getDimensions(element);
  return new Effect.Scale(element, 100, 
    Object.extend({ scaleContent: false, 
      scaleX: false,
      scaleFrom: 0,
      scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
      restoreAfterFinish: true,
      afterSetup: function(effect) { with(Element) {
        makeClipping(effect.element);
        setStyle(effect.element, {height: '0px'});
        show(effect.element); 
      }},  
      afterFinishInternal: function(effect) { with(Element) {
        undoClipping(effect.element);
        setStyle(effect.element, {height: oldHeight});
      }}
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
        beforeSetup: function(effect) { with(Element) {
          [makePositioned,makeClipping].call(effect.element);
        }},
        afterFinishInternal: function(effect) { with(Element) {
          [hide,undoClipping,undoPositioned].call(effect.element);
          setStyle(effect.element, {opacity: oldOpacity});
        }}
      })
    }
  });
}

Effect.DropOut = function(element) {
  element = $(element);
  var oldStyle = {
    top: Element.getStyle(element, 'top'),
    left: Element.getStyle(element, 'left'),
    opacity: Element.getInlineOpacity(element) };
  return new Effect.Parallel(
    [ new Effect.MoveBy(element, 100, 0, { sync: true }), 
      new Effect.Opacity(element, { sync: true, to: 0.0 }) ],
    Object.extend(
      { duration: 0.5,
        beforeSetup: function(effect) { with(Element) {
          makePositioned(effect.effects[0].element); }},
        afterFinishInternal: function(effect) { with(Element) {
          [hide, undoPositioned].call(effect.effects[0].element);
          setStyle(effect.effects[0].element, oldStyle); }} 
      }, arguments[1] || {}));
}

Effect.Shake = function(element) {
  element = $(element);
  var oldStyle = {
    top: Element.getStyle(element, 'top'),
    left: Element.getStyle(element, 'left') };
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
    { duration: 0.05, afterFinishInternal: function(effect) { with(Element) {
        undoPositioned(effect.element);
        setStyle(effect.element, oldStyle);
  }}}) }}) }}) }}) }}) }});
}

Effect.SlideDown = function(element) {
  element = $(element);
  Element.cleanWhitespace(element);
  // SlideDown need to have the content of the element wrapped in a container element with fixed height!
  var oldInnerBottom = Element.getStyle(element.firstChild, 'bottom');
  var elementDimensions = Element.getDimensions(element);
  return new Effect.Scale(element, 100, Object.extend({ 
    scaleContent: false, 
    scaleX: false, 
    scaleFrom: 0,
    scaleMode: {originalHeight: elementDimensions.height, originalWidth: elementDimensions.width},
    restoreAfterFinish: true,
    afterSetup: function(effect) { with(Element) {
      makePositioned(effect.element);
      makePositioned(effect.element.firstChild);
      if(window.opera) setStyle(effect.element, {top: ''});
      makeClipping(effect.element);
      setStyle(effect.element, {height: '0px'});
      show(element); }},
    afterUpdateInternal: function(effect) { with(Element) {
      setStyle(effect.element.firstChild, {bottom:
        (effect.dims[0] - effect.element.clientHeight) + 'px' }); }},
    afterFinishInternal: function(effect) { with(Element) {
      undoClipping(effect.element); 
      undoPositioned(effect.element.firstChild);
      undoPositioned(effect.element);
      setStyle(effect.element.firstChild, {bottom: oldInnerBottom}); }}
    }, arguments[1] || {})
  );
}
  
Effect.SlideUp = function(element) {
  element = $(element);
  Element.cleanWhitespace(element);
  var oldInnerBottom = Element.getStyle(element.firstChild, 'bottom');
  return new Effect.Scale(element, 0, 
   Object.extend({ scaleContent: false, 
    scaleX: false, 
    scaleMode: 'box',
    scaleFrom: 100,
    restoreAfterFinish: true,
    beforeStartInternal: function(effect) { with(Element) {
      makePositioned(effect.element);
      makePositioned(effect.element.firstChild);
      if(window.opera) setStyle(effect.element, {top: ''});
      makeClipping(effect.element);
      show(element); }},  
    afterUpdateInternal: function(effect) { with(Element) {
      setStyle(effect.element.firstChild, {bottom:
        (effect.dims[0] - effect.element.clientHeight) + 'px' }); }},
    afterFinishInternal: function(effect) { with(Element) {
        [hide, undoClipping].call(effect.element); 
        undoPositioned(effect.element.firstChild);
        undoPositioned(effect.element);
        setStyle(effect.element.firstChild, {bottom: oldInnerBottom}); }}
   }, arguments[1] || {})
  );
}

// Bug in opera makes the TD containing this element expand for a instance after finish 
Effect.Squish = function(element) {
  return new Effect.Scale(element, window.opera ? 1 : 0, 
    { restoreAfterFinish: true,
      beforeSetup: function(effect) { with(Element) {
        makeClipping(effect.element); }},  
      afterFinishInternal: function(effect) { with(Element) {
        hide(effect.element); 
        undoClipping(effect.element); }}
  });
}

Effect.Grow = function(element) {
  element = $(element);
  var options = Object.extend({
    direction: 'center',
    moveTransistion: Effect.Transitions.sinoidal,
    scaleTransition: Effect.Transitions.sinoidal,
    opacityTransition: Effect.Transitions.full
  }, arguments[1] || {});
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    height: element.style.height,
    width: element.style.width,
    opacity: Element.getInlineOpacity(element) };

  var dims = Element.getDimensions(element);    
  var initialMoveX, initialMoveY;
  var moveX, moveY;
  
  switch (options.direction) {
    case 'top-left':
      initialMoveX = initialMoveY = moveX = moveY = 0; 
      break;
    case 'top-right':
      initialMoveX = dims.width;
      initialMoveY = moveY = 0;
      moveX = -dims.width;
      break;
    case 'bottom-left':
      initialMoveX = moveX = 0;
      initialMoveY = dims.height;
      moveY = -dims.height;
      break;
    case 'bottom-right':
      initialMoveX = dims.width;
      initialMoveY = dims.height;
      moveX = -dims.width;
      moveY = -dims.height;
      break;
    case 'center':
      initialMoveX = dims.width / 2;
      initialMoveY = dims.height / 2;
      moveX = -dims.width / 2;
      moveY = -dims.height / 2;
      break;
  }
  
  return new Effect.MoveBy(element, initialMoveY, initialMoveX, { 
    duration: 0.01, 
    beforeSetup: function(effect) { with(Element) {
      hide(effect.element);
      makeClipping(effect.element);
      makePositioned(effect.element);
    }},
    afterFinishInternal: function(effect) {
      new Effect.Parallel(
        [ new Effect.Opacity(effect.element, { sync: true, to: 1.0, from: 0.0, transition: options.opacityTransition }),
          new Effect.MoveBy(effect.element, moveY, moveX, { sync: true, transition: options.moveTransition }),
          new Effect.Scale(effect.element, 100, {
            scaleMode: { originalHeight: dims.height, originalWidth: dims.width }, 
            sync: true, scaleFrom: window.opera ? 1 : 0, transition: options.scaleTransition, restoreAfterFinish: true})
        ], Object.extend({
             beforeSetup: function(effect) { with(Element) {
               setStyle(effect.effects[0].element, {height: '0px'});
               show(effect.effects[0].element); }},
             afterFinishInternal: function(effect) { with(Element) {
               [undoClipping, undoPositioned].call(effect.effects[0].element); 
               setStyle(effect.effects[0].element, oldStyle); }}
           }, options)
      )
    }
  });
}

Effect.Shrink = function(element) {
  element = $(element);
  var options = Object.extend({
    direction: 'center',
    moveTransistion: Effect.Transitions.sinoidal,
    scaleTransition: Effect.Transitions.sinoidal,
    opacityTransition: Effect.Transitions.none
  }, arguments[1] || {});
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    height: element.style.height,
    width: element.style.width,
    opacity: Element.getInlineOpacity(element) };

  var dims = Element.getDimensions(element);
  var moveX, moveY;
  
  switch (options.direction) {
    case 'top-left':
      moveX = moveY = 0;
      break;
    case 'top-right':
      moveX = dims.width;
      moveY = 0;
      break;
    case 'bottom-left':
      moveX = 0;
      moveY = dims.height;
      break;
    case 'bottom-right':
      moveX = dims.width;
      moveY = dims.height;
      break;
    case 'center':  
      moveX = dims.width / 2;
      moveY = dims.height / 2;
      break;
  }
  
  return new Effect.Parallel(
    [ new Effect.Opacity(element, { sync: true, to: 0.0, from: 1.0, transition: options.opacityTransition }),
      new Effect.Scale(element, window.opera ? 1 : 0, { sync: true, transition: options.scaleTransition, restoreAfterFinish: true}),
      new Effect.MoveBy(element, moveY, moveX, { sync: true, transition: options.moveTransition })
    ], Object.extend({            
         beforeStartInternal: function(effect) { with(Element) {
           [makePositioned, makeClipping].call(effect.effects[0].element) }},
         afterFinishInternal: function(effect) { with(Element) {
           [hide, undoClipping, undoPositioned].call(effect.effects[0].element);
           setStyle(effect.effects[0].element, oldStyle); }}
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
      afterFinishInternal: function(effect) { Element.setStyle(effect.element, {opacity: oldOpacity}); }
    }, options), {transition: reverser}));
}

Effect.Fold = function(element) {
  element = $(element);
  var oldStyle = {
    top: element.style.top,
    left: element.style.left,
    width: element.style.width,
    height: element.style.height };
  Element.makeClipping(element);
  return new Effect.Scale(element, 5, Object.extend({   
    scaleContent: false,
    scaleX: false,
    afterFinishInternal: function(effect) {
    new Effect.Scale(element, 1, { 
      scaleContent: false, 
      scaleY: false,
      afterFinishInternal: function(effect) { with(Element) {
        [hide, undoClipping].call(effect.element); 
        setStyle(effect.element, oldStyle);
      }} });
  }}, arguments[1] || {}));
}
