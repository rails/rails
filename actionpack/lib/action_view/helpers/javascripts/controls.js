// Copyright (c) 2005 Thomas Fuchs (http://script.aculo.us, http://mir.aculo.us)
//           (c) 2005 Ivan Krstic (http://blogs.law.harvard.edu/ivan)
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

// Autocompleter.Base handles all the autocompletion functionality 
// that's independent of the data source for autocompletion. This
// includes drawing the autocompletion menu, observing keyboard
// and mouse events, and similar.
//
// Specific autocompleters need to provide, at the very least, 
// a getUpdatedChoices function that will be invoked every time
// the text inside the monitored textbox changes. This method 
// should get the text for which to provide autocompletion by
// invoking this.getEntry(), NOT by directly accessing
// this.element.value. This is to allow incremental tokenized
// autocompletion. Specific auto-completion logic (AJAX, etc)
// belongs in getUpdatedChoices.
//
// Tokenized incremental autocompletion is enabled automatically
// when an autocompleter is instantiated with the 'tokens' option
// in the options parameter, e.g.:
// new Ajax.Autocompleter('id','upd', '/url/', { tokens: ',' });
// will incrementally autocomplete with a comma as the token.
// Additionally, ',' in the above example can be replaced with
// a token array, e.g. { tokens: new Array (',', '\n') } which
// enables autocompletion on multiple tokens. This is most 
// useful when one of the tokens is \n (a newline), as it 
// allows smart autocompletion after linebreaks.

var Autocompleter = {}
Autocompleter.Base = function() {};
Autocompleter.Base.prototype = {
  base_initialize: function(element, update, options) {
    this.element     = $(element); 
    this.update      = $(update);  
    this.has_focus   = false; 
    this.changed     = false; 
    this.active      = false; 
    this.index       = 0;     
    this.entry_count = 0;

    if (this.setOptions)
      this.setOptions(options);
    else
      this.options = {}
     
    this.options.tokens       = this.options.tokens || new Array();
    this.options.frequency    = this.options.frequency || 0.4;
    this.options.min_chars    = this.options.min_chars || 1;
    this.options.onShow       = this.options.onShow || 
    function(element, update){ 
      if(!update.style.position || update.style.position=='absolute') {
        update.style.position = 'absolute';
          var offsets = Position.cumulativeOffset(element);
          update.style.left = offsets[0] + 'px';
          update.style.top  = (offsets[1] + element.offsetHeight) + 'px';
          update.style.width = element.offsetWidth + 'px';
      }
      new Effect.Appear(update,{duration:0.15});
    };
    this.options.onHide = this.options.onHide || 
    function(element, update){ new Effect.Fade(update,{duration:0.15}) };
    
    if(this.options.indicator)
      this.indicator = $(this.options.indicator);

    if (typeof(this.options.tokens) == 'string') 
      this.options.tokens = new Array(this.options.tokens);
       
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
       'style="display:none;filter:progid:DXImageTransform.Microsoft.Alpha(opacity=0);" ' +
       'src="javascript:false;" frameborder="0" scrolling="no"></iframe>');
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
    this.updateElement(value);
    this.element.focus();
  },

  updateElement: function(value) {
    var last_token_pos = this.findLastToken();
    if (last_token_pos != -1) {
      var new_value = this.element.value.substr(0, last_token_pos + 1);
      var whitespace = this.element.value.substr(last_token_pos + 1).match(/^\s+/);
      if (whitespace)
        new_value += whitespace[0];
      this.element.value = new_value + value;
    } else {
      this.element.value = value;
    } 
  },
  
  updateChoices: function(choices) {
    if(!this.changed && this.has_focus) {
      this.update.innerHTML = choices;
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

  addObservers: function(element) {
    Event.observe(element, "mouseover", this.onHover.bindAsEventListener(this));
    Event.observe(element, "click", this.onClick.bindAsEventListener(this));
  },

  onObserverEvent: function() {
    this.changed = false;   
    if(this.getEntry().length>=this.options.min_chars) {
      this.startIndicator();
      this.getUpdatedChoices();
    } else {
      this.active = false;
      this.hide();
    }
  },

  getEntry: function() {
    var token_pos = this.findLastToken();
    if (token_pos != -1)
      var ret = this.element.value.substr(token_pos + 1).replace(/^\s+/,'').replace(/\s+$/,'');
    else
      var ret = this.element.value;
    
    return /\n/.test(ret) ? '' : ret;
  },

  findLastToken: function() {
    var last_token_pos = -1;

    for (var i=0; i<this.options.tokens.length; i++) {
      var this_token_pos = this.element.value.lastIndexOf(this.options.tokens[i]);
      if (this_token_pos > last_token_pos)
        last_token_pos = this_token_pos;
    }
    return last_token_pos;
  }
}

Ajax.Autocompleter = Class.create();
Ajax.Autocompleter.prototype = Object.extend(new Autocompleter.Base(), 
Object.extend(new Ajax.Base(), {
  initialize: function(element, update, url, options) {
	  this.base_initialize(element, update, options);
    this.options.asynchronous  = true;
    this.options.onComplete    = this.onComplete.bind(this)
    this.options.method        = 'post';
    this.options.defaultParams = this.options.parameters || null;
    this.url                   = url;
  },
  
  getUpdatedChoices: function() {
    entry = encodeURIComponent(this.element.name) + '=' + 
      encodeURIComponent(this.getEntry());
      
    this.options.parameters = this.options.callback ?
      this.options.callback(this.element, entry) : entry;
        
    if(this.options.defaultParams) 
      this.options.parameters += '&' + this.options.defaultParams;
    
    new Ajax.Request(this.url, this.options);
  },
  
  onComplete: function(request) {
    this.updateChoices(request.responseText);
  }

}));

// The local array autocompleter. Used when you'd prefer to
// inject an array of autocompletion options into the page, rather
// than sending out Ajax queries, which can be quite slow sometimes.
//
// The constructor takes four parameters. The first two are, as usual,
// the id of the monitored textbox, and id of the autocompletion menu.
// The third is the array you want to autocomplete from, and the fourth
// is the options block.
//
// Extra local autocompletion options:
// - choices - How many autocompletion choices to offer
//
// - partial_search - If false, the autocompleter will match entered
//                    text only at the beginning of strings in the 
//                    autocomplete array. Defaults to true, which will
//                    match text at the beginning of any *word* in the
//                    strings in the autocomplete array. If you want to
//                    search anywhere in the string, additionally set
//                    the option full_search to true (default: off).
//
// - full_search - Search anywhere in autocomplete array strings.
//
// - partial_chars - How many characters to enter before triggering
//                   a partial match (unlike min_chars, which defines
//                   how many characters are required to do any match
//                   at all). Defaults to 2.
//
// - ignore_case - Whether to ignore case when autocompleting.
//                 Defaults to true.
//
// It's possible to pass in a custom function as the 'selector' 
// option, if you prefer to write your own autocompletion logic.
// In that case, the other options above will not apply unless
// you support them.

Autocompleter.Local = Class.create();
Autocompleter.Local.prototype = Object.extend(new Autocompleter.Base(), {
  initialize: function(element, update, array, options) {
    this.base_initialize(element, update, options);
    this.options.array = array;
  },

  getUpdatedChoices: function() {
    this.updateChoices(this.options.selector(this));
  },

  setOptions: function(options) {
    this.options = Object.extend({
      choices: 10,
      partial_search: true,
      partial_chars: 2,
      ignore_case: true,
      full_search: false,
      selector: function(instance) {
        var ret       = new Array(); // Beginning matches
        var partial   = new Array(); // Inside matches
        var entry     = instance.getEntry();
        var count     = 0;
        
        for (var i = 0; i < instance.options.array.length &&  
            ret.length < instance.options.choices ; i++) { 
          var elem = instance.options.array[i];
          var found_pos = instance.options.ignore_case ? 
            elem.toLowerCase().indexOf(entry.toLowerCase()) : 
            elem.indexOf(entry);

          while (found_pos != -1) {
            if (found_pos == 0 && elem.length != entry.length) { 
              ret.push("<li><strong>" + elem.substr(0, entry.length) + "</strong>" + 
                elem.substr(entry.length) + "</li>");
              break;
            } else if (entry.length >= instance.options.partial_chars && 
              instance.options.partial_search && found_pos != -1) {
              if (instance.options.full_search || /\s/.test(elem.substr(found_pos-1,1))) {
                partial.push("<li>" + elem.substr(0, found_pos) + "<strong>" +
                  elem.substr(found_pos, entry.length) + "</strong>" + elem.substr(
                  found_pos + entry.length) + "</li>");
                break;
              }
            }

            found_pos = instance.options.ignore_case ? 
              elem.toLowerCase().indexOf(entry.toLowerCase(), found_pos + 1) : 
              elem.indexOf(entry, found_pos + 1);

          }
        }
        if (partial.length)
          ret = ret.concat(partial.slice(0, instance.options.choices - ret.length))
        return "<ul>" + ret.join('') + "</ul>";
      }
    }, options || {});
  }
});
