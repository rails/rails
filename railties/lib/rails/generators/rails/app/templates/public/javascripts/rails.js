document.observe("dom:loaded", function() {
  function handleRemote(element) {
    var method, url, params;

    if (element.tagName.toLowerCase() === 'form') {
      method = element.readAttribute('method') || 'post';
      url    = element.readAttribute('action');
      params = element.serialize(true);
    } else {
      method = element.readAttribute('data-method') || 'get';
      url    = element.readAttribute('href');
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

  function handleMethod(element) {
    var method, url, token_name, token;

    method     = element.readAttribute('data-method');
    url        = element.readAttribute('href');
    csrf_param = $$('meta[name=csrf-param]').first();
    csrf_token = $$('meta[name=csrf-token]').first();

    var form = new Element('form', { method: "POST", action: url, style: "display: none;" });
    element.parentNode.appendChild(form);

    if (method != 'post') {
      var field = new Element('input', { type: 'hidden', name: '_method', value: method });
      form.appendChild(field);
    }

    if (csrf_param) {
      var param = csrf_param.readAttribute('content');
      var token = csrf_token.readAttribute('content');
      var field = new Element('input', { type: 'hidden', name: param, value: token });
      form.appendChild(field);
    }

    form.submit();
  }

  $(document.body).observe("click", function(event) {
    var message = event.findElement().readAttribute('data-confirm');
    if (message && !confirm(message)) {
      event.stop();
      return false;
    }

    var element = event.findElement("a[data-remote]");
    if (element) {
      handleRemote(element);
      event.stop();
      return true;
    }

    var element = event.findElement("a[data-method]");
    if (element) {
      handleMethod(element);
      event.stop();
      return true;
    }
  });

  // TODO: I don't think submit bubbles in IE
  $(document.body).observe("submit", function(event) {
    var element = event.findElement(),
        message = element.readAttribute('data-confirm');
    if (message && !confirm(message)) {
      event.stop();
      return false;
    }

    var inputs = element.select("input[type=submit][data-disable-with]");
    inputs.each(function(input) {
      input.disabled = true;
      input.writeAttribute('data-original-value', input.value);
      input.value = input.readAttribute('data-disable-with');
    });

    var element = event.findElement("form[data-remote]");
    if (element) {
      handleRemote(element);
      event.stop();
    }
  });

  $(document.body).observe("ajax:after", function(event) {
    var element = event.findElement();

    if (element.tagName.toLowerCase() === 'form') {
      var inputs = element.select("input[type=submit][disabled=true][data-disable-with]");
      inputs.each(function(input) {
        input.value = input.readAttribute('data-original-value');
        input.writeAttribute('data-original-value', null);
        input.disabled = false;
      });
    }
  });
});