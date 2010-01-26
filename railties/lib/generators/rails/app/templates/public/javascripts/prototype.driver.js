Event.observe(document, 'dom:loaded', function() {
  function handleRemote(e, el){
    var data        = null,
        method      = el.readAttribute('method') || el.readAttribute('data-method') || 'GET',
        url         = el.readAttribute('action') || el.readAttribute('data-url') || '#',
        async       = el.readAttribute('data-remote-type') === 'synchronous' ? false : true,
        update      = el.readAttribute('data-update-success'),
        position    = el.readAttribute('data-update-position');

    if (el.readAttribute('data-submit')) {
      var submit_el = $(el.readAttribute('data-submit'));
      if(submit_el !== undefined && submit_el.tagName.toUpperCase() == 'FORM'){
        data = submit_el.serialize();
      }
    } else if (el.readAttribute('data-with')) {
        data = el.readAttribute('data-with');
    } else if(el.tagName.toUpperCase() === 'FORM') {
        data = el.serialize();
    }

    document.fire('rails:before');

    new Ajax.Request(url, {
      method: method,
      asynchronous: async,
      parameters: data,
      evalJS: true,
      evalJSON: true,
      onComplete: function(xhr){
        document.fire('rails:complete', {xhr: xhr, element: el, submitted_button: getEventProperty(e, 'submitted_button')});
      },
      onLoading: function(xhr){
        document.fire('rails:after', {xhr: xhr, element: el});
        document.fire('rails:loading', {xhr: xhr, element: el});
      },
      onLoaded: function(xhr){
        document.fire('rails:loaded', {xhr: xhr, element: el});
      },
      onSuccess: function(xhr){
        document.fire('rails:success', {xhr: xhr, element: el});
      },
      onFailure: function(xhr){
        document.fire('rails:failure', {xhr: xhr, element: el});
      }
    });

  }

  function setEventProperty(e, property, value){
    if(e.memo === undefined){
      e.memo = {};
    }

    e.memo[property] = value;
  }

  function getEventProperty(e, property){
    if(e.memo !== undefined && e.memo[property] !== undefined){
      return e.memo[property];
    }
  }

  function confirmed(e, el){
    if(getEventProperty(e,'confirm_checked') !== true){
      setEventProperty(e, 'confirm_checked', true);

      el = Event.findElement(e, 'form') || el;
      var confirm_msg = el.readAttribute('data-confirm');

      if(confirm_msg !== null){
        var result = el.fire('rails:confirm', {confirm_msg: confirm_msg});
        if(result.memo.stop_event === true){
          Event.stop(e);
          return false;
        }
      }
    }
    return true;
  }

  function disable_button(el){
    var disable_with = el.readAttribute('data-disable-with'); 
    if(disable_with !== null){
      el.writeAttribute('data-enable-with', el.readAttribute('value'));
      el.writeAttribute('value', disable_with);
      el.writeAttribute('disabled', true);
    }
  }

  function enable_button(el){
    var enable_with = el.readAttribute('data-enable-with'); 
    if(enable_with !== null){
      el.writeAttribute('value', enable_with);
    }
    el.writeAttribute('disabled', false);
  }

  function updateHTML(el, content, result){
    var element_id = null;

    if(result === 'success'){
      element_id = el.readAttribute('data-update-success');
    } else if(result === 'failure'){
      element_id = el.readAttribute('data-update-failure');
    }

    var element_to_update = $(element_id);
    if(element_to_update !== null){
      var position = el.readAttribute('data-update-position');
      if(position !== null){
        var options = {};
        options[position] = content;
        element_to_update.insert(options);
      } else {
        element_to_update.update(content);
      }
    }
  }

  /**
   *
   * Event Listeners
   *
   */

  Event.observe(document, 'submit', function (e) {
    var form = Event.findElement(e, 'form');
    // Make sure conditions and confirm have not already run
    if(form !== undefined && conditions_met(e, form) && confirmed(e, form)){

      var button = form.down('input[data-submitted=true]');
      button.writeAttribute('data-submitted', null);
      setEventProperty(e, 'submitted_button', button);
      disable_button(button);

      if(form.readAttribute('data-remote') === 'true'){
        Event.stop(e);
        handleRemote(e, form);
      }
    }
  });

  Event.observe(document, 'click', function (e) {
    var el = Event.findElement(e, 'a') || Event.findElement(e, 'input');

    if(el !== undefined && el.tagName.toUpperCase() === 'INPUT' && el.readAttribute('type').toUpperCase() === 'SUBMIT'){
      el.writeAttribute('data-submitted', 'true');
      
      // Submit is handled by submit event, don't continue on this path
      el = undefined;
    } else if(el !== undefined && el.tagName.toUpperCase() === 'INPUT' && el.readAttribute('type').toUpperCase() !== 'BUTTON'){
      // Make sure other inputs do not send this event
      el = undefined;
    }

    if(el !== undefined && conditions_met(e, el) && confirmed(e, el)){
      if(el.tagName.toUpperCase() === 'INPUT' && el.readAttribute('type').toUpperCase() === 'BUTTON'){
        disable_button(el);
      }

      if(el.readAttribute('data-remote') === 'true'){
        Event.stop(e);
        handleRemote(e, el);
      } else if(el.readAttribute('data-popup') !== null){
        Event.stop(e);
        console.log('firing rails:popup');
        document.fire('rails:popup', {element: el});
      }
    }
  });


  /**
   *
   * Default Event Handlers
   *
   */
  Event.observe(document, 'rails:confirm', function(e){
    setEventProperty(e, 'stop_event', !confirm(getEventProperty(e,'confirm_msg')));
  });

  Event.observe(document, 'rails:popup', function(e){
    console.log('in rails:popup');
    var el = getEventProperty(e, 'element');
    var url = el.readAttribute('href') || el.readAttribute('data-url');
    
    if(el.readAttribute('data-popup') === true){
      window.open(url);
    } else {
      window.open(url, el.readAttribute('data-popup'));
    }
  });

  Event.observe(document, 'rails:complete', function(e){
    var el = getEventProperty(e, 'element');

    if(el.tagName.toUpperCase() === 'FORM'){
      var button = getEventProperty(e, 'submitted_button') ;
      enable_button(button);
    }
  });

  Event.observe(document, 'rails:success', function(e){
    var el  = getEventProperty(e, 'element'),
        xhr = getEventProperty(e, 'xhr');

    if(xhr.responseText !== null){
      updateHTML(el, xhr.responseText, 'success');
    }
  });

  Event.observe(document, 'rails:failure', function(e){
    var el  = getEventProperty(e, 'element'),
        xhr = getEventProperty(e, 'xhr');

    if(xhr.responseText !== null){
      updateHTML(el, xhr.responseText, 'failure');
    }
  });

  /**
   *
   * Rails 2.x Helpers / Event Handlers 
   *
   */
  function evalAttribute(el, attribute){
    var  js = el.readAttribute('data-' + attribute);

    if(js){
      eval(js);
    }
  }

  function conditions_met(e, el){
    if(getEventProperty(e,'condition_checked') !== true){
      setEventProperty(e, 'condition_checked', true);

      el = Event.findElement(e, 'form') || el;
      var conditions = el.readAttribute('data-condition');

      if(conditions !== null){
        if(eval(conditions) === false){
          Event.stop(e);
          return false;
        }
      }
    }
    return true;
  }

  Event.observe(document, 'rails:success', function(e){
    evalAttribute('onsuccess');
  });

  Event.observe(document, 'rails:failure', function(e){
    evalAttribute('onfailure');
  });

  Event.observe(document, 'rails:complete', function(e){
    evalAttribute('oncomplete');
    evalAttribute(this, 'on' + getEventProperty('xhr', xhr.status)); 
  });

  Event.observe(document, 'rails:loading', function(e){
    evalAttribute('onloading');
  });

  Event.observe(document, 'rails:loaded', function(e){
    evalAttribute('onloaded');
  });

  Event.observe(document, 'rails:before', function(e){
    evalAttribute('onbefore');
  });

  Event.observe(document, 'rails:after', function(e){
    evalAttribute('onafter');
  });
});
