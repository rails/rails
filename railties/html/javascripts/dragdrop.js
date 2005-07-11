// Copyright (c) 2005 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
// 
// Element.Class part Copyright (c) 2005 by Rick Olson
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

Element.Class = {
    // Element.toggleClass(element, className) toggles the class being on/off
    // Element.toggleClass(element, className1, className2) toggles between both classes,
    //   defaulting to className1 if neither exist
    toggle: function(element, className) {
      if(Element.Class.has(element, className)) {
        Element.Class.remove(element, className);
        if(arguments.length == 3) Element.Class.add(element, arguments[2]);
      } else {
        Element.Class.add(element, className);
        if(arguments.length == 3) Element.Class.remove(element, arguments[2]);
      }
    },

    // gets space-delimited classnames of an element as an array
    get: function(element) {
      element = $(element);
      return element.className.split(' ');
    },

    // functions adapted from original functions by Gavin Kistner
    remove: function(element) {
      element = $(element);
      var regEx;
      for(var i = 1; i < arguments.length; i++) {
        regEx = new RegExp("^" + arguments[i] + "\\b\\s*|\\s*\\b" + arguments[i] + "\\b", 'g');
        element.className = element.className.replace(regEx, '')
      }
    },

    add: function(element) {
      element = $(element);
      for(var i = 1; i < arguments.length; i++) {
        Element.Class.remove(element, arguments[i]);
        element.className += (element.className.length > 0 ? ' ' : '') + arguments[i];
      }
    },

    // returns true if all given classes exist in said element
    has: function(element) {
      element = $(element);
      if(!element || !element.className) return false;
      var regEx;
      for(var i = 1; i < arguments.length; i++) {
        regEx = new RegExp("\\b" + arguments[i] + "\\b");
        if(!regEx.test(element.className)) return false;
      }
      return true;
    },
    
    // expects arrays of strings and/or strings as optional paramters
    // Element.Class.has_any(element, ['classA','classB','classC'], 'classD')
    has_any: function(element) {
      element = $(element);
      if(!element || !element.className) return false;
      var regEx;
      for(var i = 1; i < arguments.length; i++) {
        if((typeof arguments[i] == 'object') && 
          (arguments[i].constructor == Array)) {
          for(var j = 0; j < arguments[i].length; j++) {
            regEx = new RegExp("\\b" + arguments[i][j] + "\\b");
            if(regEx.test(element.className)) return true;
          }
        } else {
          regEx = new RegExp("\\b" + arguments[i] + "\\b");
          if(regEx.test(element.className)) return true;
        }
      }
      return false;
    },
    
    childrenWith: function(element, className) {
      var children = $(element).getElementsByTagName('*');
      var elements = new Array();
      
      for (var i = 0; i < children.length; i++) {
        if (Element.Class.has(children[i], className)) {
          elements.push(children[i]);
          break;
        }
      }
      
      return elements;
    }
}

/*--------------------------------------------------------------------------*/

var Droppables = {
  drops: false,
  
  remove: function(element) {
    for(var i = 0; i < this.drops.length; i++)
      if(this.drops[i].element == element)
        this.drops.splice(i,1);
  },
  
  add: function(element) {
    var element = $(element);
    var options = Object.extend({
      greedy:     true,
      hoverclass: null  
    }, arguments[1] || {});
    
    // cache containers
    if(options.containment) {
      options._containers = new Array();
      var containment = options.containment;
      if((typeof containment == 'object') && 
        (containment.constructor == Array)) {
        for(var i=0; i<containment.length; i++)
          options._containers.push($(containment[i]));
      } else {
        options._containers.push($(containment));
      }
      options._containers_length = 
        options._containers.length-1;
    }
    
    Element.makePositioned(element); // fix IE
    
    options.element = element;
    
    // activate the droppable    
    if(!this.drops) this.drops = [];
    this.drops.push(options);
  },
  
  is_contained: function(element, drop) {
    var containers = drop._containers;
    var parentNode = element.parentNode;
    var i = drop._containers_length;
    do { if(parentNode==containers[i]) return true; } while (i--);
    return false;
  },
  
  is_affected: function(pX, pY, element, drop) {
    return (
      (drop.element!=element) &&
      ((!drop._containers) ||
        this.is_contained(element, drop)) &&
      ((!drop.accept) ||
        (Element.Class.has_any(element, drop.accept))) &&
      Position.within(drop.element, pX, pY) );
  },
  
  deactivate: function(drop) {
    Element.Class.remove(drop.element, drop.hoverclass);
    this.last_active = null;
  },
  
  activate: function(drop) {
    if(this.last_active) this.deactivate(this.last_active);
    if(drop.hoverclass) {
      Element.Class.add(drop.element, drop.hoverclass);
      this.last_active = drop;
    }
  },
  
  show: function(event, element) {
    if(!this.drops) return;
    var pX = Event.pointerX(event);
    var pY = Event.pointerY(event);
    Position.prepare();
    
    var i = this.drops.length-1; do {
      var drop = this.drops[i];
      if(this.is_affected(pX, pY, element, drop)) {
        if(drop.onHover)
           drop.onHover(element, drop.element, Position.overlap(drop.overlap, drop.element));
        if(drop.greedy) { 
          this.activate(drop);
          return;
        }
      }
    } while (i--);
  },
  
  fire: function(event, element) {
    if(!this.last_active) return;
    Position.prepare();
    
    if (this.is_affected(Event.pointerX(event), Event.pointerY(event), element, this.last_active))
      if (this.last_active.onDrop) 
        this.last_active.onDrop(element, this.last_active);
    
  },
  
  reset: function() {
    if(this.last_active)
      this.deactivate(this.last_active);
  }
}

Draggables = {
  observers: new Array(),
  addObserver: function(observer) {
    this.observers.push(observer);    
  },
  removeObserver: function(element) {  // element instead of obsever fixes mem leaks
    for(var i = 0; i < this.observers.length; i++)
      if(this.observers[i].element && (this.observers[i].element == element))
        this.observers.splice(i,1);
  },
  notify: function(eventName, draggable) {  // 'onStart', 'onEnd'
    for(var i = 0; i < this.observers.length; i++)
      this.observers[i][eventName](draggable);
  }
}

/*--------------------------------------------------------------------------*/

Draggable = Class.create();
Draggable.prototype = {
  initialize: function(element) {
    var options = Object.extend({
      handle: false,
      starteffect: function(element) { 
        new Effect.Opacity(element, {duration:0.2, from:1.0, to:0.7}); 
      },
      reverteffect: function(element, top_offset, left_offset) {
        new Effect.MoveBy(element, -top_offset, -left_offset, {duration:0.4});
      },
      endeffect: function(element) { 
         new Effect.Opacity(element, {duration:0.2, from:0.7, to:1.0}); 
      },
      zindex: 1000,
      revert: false
    }, arguments[1] || {});
    
    this.element      = $(element);
    this.handle       = options.handle ? $(options.handle) : this.element;
    
    Element.makePositioned(this.element); // fix IE
    
    this.offsetX      = 0;
    this.offsetY      = 0;
    this.originalLeft = this.currentLeft();
    this.originalTop  = this.currentTop();
    this.originalX    = this.element.offsetLeft;
    this.originalY    = this.element.offsetTop;
    this.originalZ    = parseInt(this.element.style.zIndex || "0");
    
    this.options      = options;
    
    this.active       = false;
    this.dragging     = false;   
    
    this.eventMouseDown = this.startDrag.bindAsEventListener(this);
    this.eventMouseUp   = this.endDrag.bindAsEventListener(this);
    this.eventMouseMove = this.update.bindAsEventListener(this);
    this.eventKeypress  = this.keyPress.bindAsEventListener(this);
    
    Event.observe(this.handle, "mousedown", this.eventMouseDown);
    Event.observe(document, "mouseup", this.eventMouseUp);
    Event.observe(document, "mousemove", this.eventMouseMove);
    Event.observe(document, "keypress", this.eventKeypress);
  },
  destroy: function() {
    Event.stopObserving(this.handle, "mousedown", this.eventMouseDown);
    Event.stopObserving(document, "mouseup", this.eventMouseUp);
    Event.stopObserving(document, "mousemove", this.eventMouseMove);
    Event.stopObserving(document, "keypress", this.eventKeypress);
  },
  currentLeft: function() {
    return parseInt(this.element.style.left || '0');
  },
  currentTop: function() {
    return parseInt(this.element.style.top || '0')
  },
  startDrag: function(event) {
    if(Event.isLeftClick(event)) {
      this.active = true;
      
      var style = this.element.style;
      this.originalY = this.element.offsetTop  - this.currentTop()  - this.originalTop;
      this.originalX = this.element.offsetLeft - this.currentLeft() - this.originalLeft;
      this.offsetY =  event.clientY - this.originalY - this.originalTop;
      this.offsetX =  event.clientX - this.originalX - this.originalLeft;
      
      Event.stop(event);
    }
  },
  finishDrag: function(event, success) {
    this.active = false;
    this.dragging = false;
    
    if(success) Droppables.fire(event, this.element);
    Draggables.notify('onEnd', this);
    
    var revert = this.options.revert;
    if(revert && typeof revert == 'function') revert = revert(this.element);
      
    if(revert && this.options.reverteffect) {
      this.options.reverteffect(this.element, 
      this.currentTop()-this.originalTop,
      this.currentLeft()-this.originalLeft);
    } else {
      this.originalLeft = this.currentLeft();
      this.originalTop  = this.currentTop();
    }
    
    this.element.style.zIndex = this.originalZ;
      
    if(this.options.endeffect) 
      this.options.endeffect(this.element);
      
    Droppables.reset();
  },
  keyPress: function(event) {
    if(this.active) {
      if(event.keyCode==Event.KEY_ESC) {
        this.finishDrag(event, false);
        Event.stop(event);
      }
    }
  },
  endDrag: function(event) {
    if(this.active && this.dragging) {
      this.finishDrag(event, true);
      Event.stop(event);
    }
    this.active = false;
    this.dragging = false;
  },
  draw: function(event) {
    var style = this.element.style;
    this.originalX = this.element.offsetLeft - this.currentLeft() - this.originalLeft;
    this.originalY = this.element.offsetTop  - this.currentTop()  - this.originalTop;
    if((!this.options.constraint) || (this.options.constraint=='horizontal'))
      style.left = ((event.clientX - this.originalX) - this.offsetX) + "px";
    if((!this.options.constraint) || (this.options.constraint=='vertical'))
      style.top  = ((event.clientY - this.originalY) - this.offsetY) + "px";
    if(style.visibility=="hidden") style.visibility = ""; // fix gecko rendering
  },
  update: function(event) {
   if(this.active) {
      if(!this.dragging) {
        var style = this.element.style;
        this.dragging = true;
        if(style.position=="") style.position = "relative";
        style.zIndex = this.options.zindex;
        Draggables.notify('onStart', this);
        if(this.options.starteffect) this.options.starteffect(this.element);
      }
      
      Droppables.show(event, this.element);
      this.draw(event);
      if(this.options.change) this.options.change(this);
      
      // fix AppleWebKit rendering
      if(navigator.appVersion.indexOf('AppleWebKit')>0) window.scrollBy(0,0); 
      
      Event.stop(event);
   }
  }
}

/*--------------------------------------------------------------------------*/

SortableObserver = Class.create();
SortableObserver.prototype = {
  initialize: function(element, observer) {
    this.element   = $(element);
    this.observer  = observer;
    this.lastValue = Sortable.serialize(this.element);
  },
  onStart: function() {
    this.lastValue = Sortable.serialize(this.element);
  },
  onEnd: function() {    
    if(this.lastValue != Sortable.serialize(this.element))
      this.observer(this.element)
  }
}

Sortable = {
  sortables: new Array(),
  options: function(element){
    var element = $(element);
    for(var i=0;i<this.sortables.length;i++)
      if(this.sortables[i].element == element)
        return this.sortables[i];
    return null;        
  },
  destroy: function(element){
    var element = $(element);
    for(var i=0;i<this.sortables.length;i++) {
      if(this.sortables[i].element == element) {
        var s = this.sortables[i];
        Draggables.removeObserver(s.element);
        for(var j=0;j<s.droppables.length;j++)
          Droppables.remove(s.droppables[j]);
        for(var j=0;j<s.draggables.length;j++)
          s.draggables[j].destroy();
        this.sortables.splice(i,1);
      }
    }
  },
  create: function(element) {
    var element = $(element);
    var options = Object.extend({ 
      element:     element,
      tag:         'li',       // assumes li children, override with tag: 'tagname'
      overlap:     'vertical', // one of 'vertical', 'horizontal'
      constraint:  'vertical', // one of 'vertical', 'horizontal', false
      containment: element,    // also takes array of elements (or id's); or false
      handle:      false,      // or a CSS class
      only:        false,
      hoverclass:  null,
      onChange:    function() {},
      onUpdate:    function() {}
    }, arguments[1] || {});
    
    // clear any old sortable with same element
    this.destroy(element);
    
    // build options for the draggables
    var options_for_draggable = {
      revert:      true,
      constraint:  options.constraint,
      handle:      handle };
    if(options.starteffect)
      options_for_draggable.starteffect = options.starteffect;
    if(options.reverteffect)
      options_for_draggable.reverteffect = options.reverteffect;
    if(options.endeffect)
      options_for_draggable.endeffect = options.endeffect;
    if(options.zindex)
      options_for_draggable.zindex = options.zindex;
    
    // build options for the droppables  
    var options_for_droppable = {
      overlap:     options.overlap,
      containment: options.containment,
      hoverclass:  options.hoverclass,
      onHover: function(element, dropon, overlap) { 
        if(overlap>0.5) {
          if(dropon.previousSibling != element) {
            var oldParentNode = element.parentNode;
            element.style.visibility = "hidden"; // fix gecko rendering
            dropon.parentNode.insertBefore(element, dropon);
            if(dropon.parentNode!=oldParentNode && oldParentNode.sortable) 
              oldParentNode.sortable.onChange(element);
            if(dropon.parentNode.sortable)
              dropon.parentNode.sortable.onChange(element);
          }
        } else {                
          var nextElement = dropon.nextSibling || null;
          if(nextElement != element) {
            var oldParentNode = element.parentNode;
            element.style.visibility = "hidden"; // fix gecko rendering
            dropon.parentNode.insertBefore(element, nextElement);
            if(dropon.parentNode!=oldParentNode && oldParentNode.sortable) 
              oldParentNode.sortable.onChange(element);
            if(dropon.parentNode.sortable)
              dropon.parentNode.sortable.onChange(element);
          }
        }
      }
    }

    // fix for gecko engine
    Element.cleanWhitespace(element); 
    
    options.draggables = [];
    options.droppables = [];
    
    // make it so 
    var elements = element.childNodes;
    for (var i = 0; i < elements.length; i++) 
      if(elements[i].tagName && elements[i].tagName==options.tag.toUpperCase() &&
        (!options.only || (Element.Class.has(elements[i], options.only)))) {
        
        // handles are per-draggable
        var handle = options.handle ? 
          Element.Class.childrenWith(elements[i], options.handle)[0] : elements[i];
        
        options.draggables.push(new Draggable(elements[i], Object.extend(options_for_draggable, { handle: handle })));
        
        Droppables.add(elements[i], options_for_droppable);
        options.droppables.push(elements[i]);
        
      }
      
    // keep reference
    this.sortables.push(options);
    
    // for onupdate
    Draggables.addObserver(new SortableObserver(element, options.onUpdate));

  },
  serialize: function(element) {
    var element = $(element);
    var sortableOptions = this.options(element);
    var options = Object.extend({
      tag:  sortableOptions.tag,
      only: sortableOptions.only,
      name: element.id
    }, arguments[1] || {});
    
    var items = $(element).childNodes;
    var queryComponents = new Array();
 
    for(var i=0; i<items.length; i++)
      if(items[i].tagName && items[i].tagName==options.tag.toUpperCase() &&
        (!options.only || (Element.Class.has(items[i], options.only))))
        queryComponents.push(
          encodeURIComponent(options.name) + "[]=" + 
          encodeURIComponent(items[i].id.split("_")[1]));

    return queryComponents.join("&");
  }
} 