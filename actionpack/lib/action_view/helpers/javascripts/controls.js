// Copyright (c) 2005 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
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

Ajax.Autocompleter = Class.create();
Ajax.Autocompleter.prototype = (new Ajax.Base()).extend({
  initialize: function(element, update, url, options) {
    this.element     = $(element); 
    this.update      = $(update);  
    this.has_focus   = false; 
    this.changed     = false; 
    this.active      = false; 
    this.index       = 0;     
    this.entry_count = 0;    
    this.url         = url;

    this.setOptions(options);
    this.options.asynchronous = true;
    this.options.onComplete   = this.onComplete.bind(this)
    this.options.frequency    = this.options.frequency || 0.4;
    this.options.min_chars    = this.options.min_chars || 1;
    this.options.method       = 'post';
    
    this.options.onShow = this.options.onShow || 
      function(element, update){ 
        if(!update.style.position || update.style.position=='absolute') {
          update.style.position = 'absolute';
          var offsets = Position.cumulativeOffset(element);
          update.style.left = offsets[0] + 'px';
          update.style.top  = (offsets[1] + element.offsetHeight) + 'px';
          update.style.width = element.offsetWidth + 'px';
        }
        new Effect.Appear(update,{duration:0.3});
      };
    this.options.onHide = this.options.onHide || 
      function(element, update){ new Effect.Fade(update,{duration:0.3}) };
    
    
    if(this.options.indicator)
      this.indicator = $(this.options.indicator);
       
    this.observer = null;
    
    Element.hide(this.update);
    
    Event.observe(this.element, "blur", this.onBlur.bindAsEventListener(this));
    Event.observe(this.element, "keypress", this.onKeyPress.bindAsEventListener(this));
  },
  
  show: function() {
    if(this.update.style.display=='none') this.options.onShow(this.element, this.update);
    if(!this.iefix && (navigator.appVersion.indexOf('MSIE')>0) && this.update.style.position=='absolute') {
      new Insertion.After(this.update, 
       '<iframe id="' + this.update.id + '_iefix" '+
       'style="display:none;filter:progid:DXImageTransform.Microsoft.Alpha(apacity=0);" ' +
       'src="javascript:;" frameborder="0" scrolling="no"></iframe>');
      this.iefix = $(this.update.id+'_iefix');
    }
    if(this.iefix) {
      Position.clone(this.update, this.iefix);
      this.iefix.style.zIndex = 1;
      this.update.style.zIndex = 2;
      Element.show(this.iefix);
    }
  },
  
  hide: function() {
    if(this.update.style.display=='') this.options.onHide(this.element, this.update);
    if(this.iefix) Element.hide(this.iefix);
  },
  
  startIndicator: function() {
    if(this.indicator) Element.show(this.indicator);
  },
  
  stopIndicator: function() {
    if(this.indicator) Element.hide(this.indicator);
  },
  
  onObserverEvent: function() {
    this.changed = false;   
    if(this.element.value.length>=this.options.min_chars) {
      this.startIndicator();
      this.options.parameters = this.options.callback ?
        this.options.callback(this.element, Form.Element.getValue(this.element)) :
          Form.Element.serialize(this.element);
      new Ajax.Request(this.url, this.options);
    } else {
      this.active = false;
      this.hide();
    }
  },
  
  addObservers: function(element) {
    Event.observe(element, "mouseover", this.onHover.bindAsEventListener(this));
    Event.observe(element, "click", this.onClick.bindAsEventListener(this));
  },
  
  onComplete: function(request) {
    if(!this.changed && this.has_focus) {
      this.update.innerHTML = request.responseText;
      Element.cleanWhitespace(this.update);
      Element.cleanWhitespace(this.update.firstChild);

      if(this.update.firstChild && this.update.firstChild.childNodes) {
        this.entry_count = 
          this.update.firstChild.childNodes.length;
        for (var i = 0; i < this.entry_count; i++) {
          entry = this.get_entry(i);
          entry.autocompleteIndex = i;
          this.addObservers(entry);
        }
      } else { 
        this.entry_count = 0;
      }
      
      this.stopIndicator();
      
      this.index = 0;
      this.render();
    }
  },
  
  onKeyPress: function(event) {
    if(this.active)
      switch(event.keyCode) {
       case Event.KEY_TAB:
       case Event.KEY_RETURN:
         this.select_entry();
         Event.stop(event);
       case Event.KEY_ESC:
         this.hide();
         this.active = false;
         return;
       case Event.KEY_LEFT:
       case Event.KEY_RIGHT:
         return;
       case Event.KEY_UP:
         this.mark_previous();
         this.render();
         if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
         return;
       case Event.KEY_DOWN:
         this.mark_next();
         this.render();
         if(navigator.appVersion.indexOf('AppleWebKit')>0) Event.stop(event);
         return;
      }
     else 
      if(event.keyCode==Event.KEY_TAB || event.keyCode==Event.KEY_RETURN) 
        return;
    
    this.changed = true;
    this.has_focus = true;
    
    if(this.observer) clearTimeout(this.observer);
      this.observer = 
        setTimeout(this.onObserverEvent.bind(this), this.options.frequency*1000);
  },
  
  onHover: function(event) {
    var element = Event.findElement(event, 'LI');
    if(this.index != element.autocompleteIndex) 
    {
        this.index = element.autocompleteIndex;
        this.render();
    }
    Event.stop(event);
  },
  
  onClick: function(event) {
    var element = Event.findElement(event, 'LI');
    this.index = element.autocompleteIndex;
    this.select_entry();
    Event.stop(event);
  },
  
  onBlur: function(event) {
    // needed to make click events working
    setTimeout(this.hide.bind(this), 250);
    this.has_focus = false;
    this.active = false;     
  }, 
  
  render: function() {
    if(this.entry_count > 0) {
      for (var i = 0; i < this.entry_count; i++)
        this.index==i ? 
          Element.addClassName(this.get_entry(i),"selected") : 
          Element.removeClassName(this.get_entry(i),"selected");
        
      if(this.has_focus) { 
        if(this.get_current_entry().scrollIntoView) 
          this.get_current_entry().scrollIntoView(false);
        
        this.show();
        this.active = true;
      }
    } else this.hide();
  },
  
  mark_previous: function() {
    if(this.index > 0) this.index--
      else this.index = this.entry_count-1;
  },
  
  mark_next: function() {
    if(this.index < this.entry_count-1) this.index++
      else this.index = 0;
  },
  
  get_entry: function(index) {
    return this.update.firstChild.childNodes[index];
  },
  
  get_current_entry: function() {
    return this.get_entry(this.index);
  },
  
  select_entry: function() {
    this.active = false;
    value = Element.collectTextNodesIgnoreClass(this.get_current_entry(), 'informal').unescapeHTML();
    this.element.value = value;
    this.element.focus();
  }
});