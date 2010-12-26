(function() {
  // Technique from Juriy Zaytsev
  // http://thinkweb2.com/projects/prototype/detecting-event-support-without-browser-sniffing/
  function isEventSupported(eventName) {
    var el = document.createElement('div');
    eventName = 'on' + eventName;
    var isSupported = (eventName in el);
    if (!isSupported) {
      el.setAttribute(eventName, 'return;');
      isSupported = typeof el[eventName] == 'function';
    }
    el = null;
    return isSupported;
  }

  function isForm(element) {
    return Object.isElement(element) && element.nodeName.toUpperCase() == 'FORM';
  }

  function isInput(element) {
    if (Object.isElement(element)) {
      var name = element.nodeName.toUpperCase();
      return name == 'INPUT' || name == 'SELECT' || name == 'TEXTAREA';
    }
    else return false;
  }

  var submitBubbles = isEventSupported('submit'),
      changeBubbles = isEventSupported('change');

  if (!submitBubbles || !changeBubbles) {
    // augment the Event.Handler class to observe custom events when needed
    Event.Handler.prototype.initialize = Event.Handler.prototype.initialize.wrap(
      function(init, element, eventName, selector, callback) {
        init(element, eventName, selector, callback);
        // is the handler being attached to an element that doesn't support this event?
        if ( (!submitBubbles && this.eventName == 'submit' && !isForm(this.element)) ||
             (!changeBubbles && this.eventName == 'change' && !isInput(this.element)) ) {
          // "submit" => "emulated:submit"
          this.eventName = 'emulated:' + this.eventName;
        }
      }
    );
  }

  if (!submitBubbles) {
    // discover forms on the page by observing focus events which always bubble
    document.on('focusin', 'form', function(focusEvent, form) {
      // special handler for the real "submit" event (one-time operation)
      if (!form.retrieve('emulated:submit')) {
        form.on('submit', function(submitEvent) {
          var emulated = form.fire('emulated:submit', submitEvent, true);
          // if custom event received preventDefault, cancel the real one too
          if (emulated.returnValue === false) submitEvent.preventDefault();
        });
        form.store('emulated:submit', true);
      }
    });
  }

  if (!changeBubbles) {
    // discover form inputs on the page
    document.on('focusin', 'input, select, textarea', function(focusEvent, input) {
      // special handler for real "change" events
      if (!input.retrieve('emulated:change')) {
        input.on('change', function(changeEvent) {
          input.fire('emulated:change', changeEvent, true);
        });
        input.store('emulated:change', true);
      }
    });
  }

  function handleRemote(element) {
    var method, url, params;

    var event = element.fire("ajax:before");
    if (event.stopped) return false;

    if (element.tagName.toLowerCase() === 'form') {
      method = element.readAttribute('method') || 'post';
      url    = element.readAttribute('action');
      // serialize the form with respect to the submit button that was pressed
      params = element.serialize({ submit: element.retrieve('rails:submit-button') });
      // clear the pressed submit button information
      element.store('rails:submit-button', null);
    } else {
      method = element.readAttribute('data-method') || 'get';
      url    = element.readAttribute('href');
      params = {};
    }

    new Ajax.Request(url, {
      method: method,
      parameters: params,
      evalScripts: true,

      onCreate:   function(response) { element.fire("ajax:create",   response); },
      onComplete: function(response) { element.fire("ajax:complete", response); },
      onSuccess:  function(response) { element.fire("ajax:success",  response); },
      onFailure:  function(response) { element.fire("ajax:failure",  response); }
    });

    element.fire("ajax:after");
  }

  function insertHiddenField(form, name, value) {
    form.insert(new Element('input', { type: 'hidden', name: name, value: value }));
  }

  function handleMethod(element) {
    var method = element.readAttribute('data-method'),
        url = element.readAttribute('href'),
        csrf_param = $$('meta[name=csrf-param]')[0],
        csrf_token = $$('meta[name=csrf-token]')[0];

    var form = new Element('form', { method: "POST", action: url, style: "display: none;" });
    $(element.parentNode).insert(form);

    if (method !== 'post') {
      insertHiddenField(form, '_method', method);
    }

    if (csrf_param) {
      insertHiddenField(form, csrf_param.readAttribute('content'), csrf_token.readAttribute('content'));
    }

    form.submit();
  }

  function disableFormElements(form) {
    form.select('input[type=submit][data-disable-with]').each(function(input) {
      input.store('rails:original-value', input.getValue());
      input.setValue(input.readAttribute('data-disable-with')).disable();
    });
  }
  
  function enableFormElements(form) {
    form.select('input[type=submit][data-disable-with]').each(function(input) {
      input.setValue(input.retrieve('rails:original-value')).enable();
    });
  }

  function allowAction(element) {
    var message = element.readAttribute('data-confirm');
    return !message || confirm(message);
  }

  document.on('click', 'a[data-confirm], a[data-remote], a[data-method]', function(event, link) {
    if (!allowAction(link)) {
      event.stop();
      return false;
    }

    if (link.readAttribute('data-remote')) {
      handleRemote(link);
      event.stop();
    } else if (link.readAttribute('data-method')) {
      handleMethod(link);
      event.stop();
    }
  });

  document.on("click", "form input[type=submit], form button[type=submit], form button:not([type])", function(event, button) {
    // register the pressed submit button
    event.findElement('form').store('rails:submit-button', button.name || false);
  });

  document.on("submit", function(event) {
    var form = event.findElement();

    if (!allowAction(form)) {
      event.stop();
      return false;
    }

    if (form.readAttribute('data-remote')) {
      handleRemote(form);
      event.stop();
    } else {
      disableFormElements(form);
    }
  });

  document.on('ajax:create', 'form', function(event, form) {
    if (form == event.findElement()) disableFormElements(form);
  });
  
  document.on('ajax:complete', 'form', function(event, form) {
    if (form == event.findElement()) enableFormElements(form);
  });
})();
