document.observe("dom:loaded", function() {
  function handleRemote(element) {
    var method, url, params;

    if (element.tagName.toLowerCase() == 'form') {
      method = element.readAttribute('method') || 'post';
      url    = element.readAttribute('action');
      params = element.serialize(true);
    } else {
      method = element.readAttribute('data-method') || 'get';
      // TODO: data-url support is going away, just use href
      url    = element.readAttribute('data-url') || element.readAttribute('href');
      params = {};
    }

    var event = element.fire("ajax:before");
    if (event.stopped) return false;

    new Ajax.Request(url, {
      method: method,
      parameters: params,
      asynchronous: true,
      evalScripts: true,

      onLoading:     function(request) { element.fire("ajax:loading", {request: request}); },
      onLoaded:      function(request) { element.fire("ajax:loaded", {request: request}); },
      onInteractive: function(request) { element.fire("ajax:interactive", {request: request}); },
      onComplete:    function(request) { element.fire("ajax:complete", {request: request}); },
      onSuccess:     function(request) { element.fire("ajax:success", {request: request}); },
      onFailure:     function(request) { element.fire("ajax:failure", {request: request}); }
    });

    element.fire("ajax:after");
  }

  $(document.body).observe("click", function(event) {
    var element = event.findElement("a[data-remote=true]");
    if (element) {
      handleRemote(element);
      event.stop();
    }
  });

  $(document.body).observe("ajax:before", function(event) {
    var message = event.element().readAttribute('data-confirm');
    if (message && !confirm(message)) event.stop();
  });

  // TODO: I don't think submit bubbles in IE
  $(document.body).observe("submit", function(event) {
    var inputs = event.element().select("input[type=submit][data-disable-with]");
    inputs.each(function(input) {
      input.disabled = true;
      input.writeAttribute('data-original-value', input.value);
      input.value = input.readAttribute('data-disable-with');
    });

    var element = event.findElement("form[data-remote=true]");
    if (element) {
      handleRemote(element);
      event.stop();
    }
  });

  $(document.body).observe("ajax:complete", function(event) {
    var element = event.element();

    if (element.tagName.toLowerCase() == 'form') {
      var inputs = element.select("input[type=submit][disabled=true][data-disable-with]");
      inputs.each(function(input) {
        input.value = input.readAttribute('data-original-value');
        input.writeAttribute('data-original-value', null);
        input.disabled = false;
      });
    }
  });
});
