document.observe("dom:loaded", function() {
  var authToken = $$('meta[name=csrf-token]').first().readAttribute('content'),
    authParam = $$('meta[name=csrf-param]').first().readAttribute('content'),
    formTemplate = '<form method="#{method}" action="#{action}">\
      #{realmethod}<input name="#{param}" value="#{token}" type="hidden">\
      </form>',
    realmethodTemplate = '<input name="_method" value="#{method}" type="hidden">';

  function handleRemote(element) {
    var method, url, params;

    if (element.tagName.toLowerCase() == 'form') {
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

  $(document.body).observe("click", function(event) {
    var message = event.element().readAttribute('data-confirm');
    if (message && !confirm(message)) {
      event.stop();
      return false;
    }

    var element = event.findElement("a[data-remote=true]");
    if (element) {
      handleRemote(element);
      event.stop();
    }

    var element = event.findElement("a[data-method]");
    if (element && element.readAttribute('data-remote') != 'true') {
      var method = element.readAttribute('data-method'),
        piggyback = method.toLowerCase() != 'post',
        formHTML = formTemplate.interpolate({
          method: 'POST',
          realmethod: piggyback ? realmethodTemplate.interpolate({ method: method }) : '',
          action: element.readAttribute('href'),
          token: authToken,
          param: authParam
        });

      var form = new Element('div').update(formHTML).down().hide();
      this.insert({ bottom: form });

      form.submit();
      event.stop();
    }
  });

  // TODO: I don't think submit bubbles in IE
  $(document.body).observe("submit", function(event) {
    var message = event.element().readAttribute('data-confirm');
    if (message && !confirm(message)) {
      event.stop();
      return false;
    }

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
