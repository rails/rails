(function() {

module('call-remote-callbacks', {
  setup: function() {
    $('#qunit-fixture').append($('<form />', {
      action: '/echo', method: 'get', 'data-remote': 'true'
    }))
  },
  teardown: function() {
    $(document).undelegate('form[data-remote]', 'ajax:beforeSend')
    $(document).undelegate('form[data-remote]', 'ajax:before')
    $(document).undelegate('form[data-remote]', 'ajax:send')
    $(document).undelegate('form[data-remote]', 'ajax:complete')
    $(document).undelegate('form[data-remote]', 'ajax:success')
    $(document).unbind('ajaxStop')
    $(document).unbind('iframe:loading')
  }
})

function start_after_submit(form) {
  form.bindNative('ajax:complete', function() {
    ok(true, 'ajax:complete')
    start()
  })
}

function submit(fn) {
  var form = $('form')
  start_after_submit(form)

  if (fn) fn(form)
  form.triggerNative('submit')
}

function submit_with_button(submit_button) {
  var form = $('form')
  start_after_submit(form)

  submit_button.triggerNative('click')
}

asyncTest('modifying form fields with "ajax:before" sends modified data in request', 4, function() {
  $('form[data-remote]')
    .append($('<input type="text" name="user_name" value="john">'))
    .append($('<input type="text" name="removed_user_name" value="john">'))
    .bindNative('ajax:before', function() {
      var form = $(this)
      form
        .append($('<input />', {name: 'other_user_name', value: 'jonathan'}))
        .find('input[name="removed_user_name"]').remove()
      form
        .find('input[name="user_name"]').val('steve')
    })

  submit(function(form) {
    form.bindNative('ajax:success', function(e, data, status, xhr) {
      equal(data.params.user_name, 'steve', 'modified field value should have been submitted')
      equal(data.params.other_user_name, 'jonathan', 'added field value should have been submitted')
      equal(data.params.removed_user_name, undefined, 'removed field value should be undefined')
    })
  })
})

asyncTest('modifying data("type") with "ajax:before" requests new dataType in request', 2, function() {
  $('form[data-remote]').data('type', 'html')
    .bindNative('ajax:before', function() {
      this.setAttribute('data-type', 'xml')
    })

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      equal(settings.dataType, 'xml', 'modified dataType should have been requested')
    })
  })
})

asyncTest('setting data("with-credentials",true) with "ajax:before" uses new setting in request', 2, function() {
  $('form[data-remote]').data('with-credentials', false)
    .bindNative('ajax:before', function() {
      this.setAttribute('data-with-credentials', true)
    })

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      equal(settings.withCredentials, true, 'setting modified in ajax:before should have forced withCredentials request')
    })
  })
})

asyncTest('stopping the "ajax:beforeSend" event aborts the request', 1, function() {
  submit(function(form) {
    form.bindNative('ajax:beforeSend', function() {
      ok(true, 'aborting request in ajax:beforeSend')
      return false
    })
    form.unbind('ajax:send').bindNative('ajax:send', function() {
      ok(false, 'ajax:send should not run')
    })
    form.unbind('ajax:complete').bindNative('ajax:complete', function() {
      ok(false, 'ajax:complete should not run')
    })
    form.bindNative('ajax:error', function(e, xhr, status, error) {
      ok(false, 'ajax:error should not run')
    })
    $(document).bindNative('ajaxStop', function() {
      start()
    })
  })
})

asyncTest('blank required form input field should abort request and trigger "ajax:aborted:required" event', 5, function() {
  $(document).bind('iframe:loading', function() {
    ok(false, 'form should not get submitted')
  })

  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .append($('<textarea name="user_bio" required="required"></textarea>'))
    .bindNative('ajax:beforeSend', function() {
      ok(false, 'ajax:beforeSend should not run')
    })
    .bindNative('ajax:aborted:required', function(e, data) {
      data = $(data)
      ok(data.length == 2, 'ajax:aborted:required event is passed all blank required inputs (jQuery objects)')
      ok(data.first().is('input[name="user_name"]'), 'ajax:aborted:required adds blank required input to data')
      ok(data.last().is('textarea[name="user_bio"]'), 'ajax:aborted:required adds blank required textarea to data')
      ok(true, 'ajax:aborted:required should run')
    })
    .triggerNative('submit')

  setTimeout(function() {
    form.find('input[required],textarea[required]').val('Tyler')
    form.unbind('ajax:beforeSend')
    submit()
  }, 13)
})

asyncTest('blank required form input for non-remote form should abort normal submission', 1, function() {
  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .removeAttr('data-remote')
    .bindNative('ujs:everythingStopped', function() {
      ok(true, 'ujs:everythingStopped should run')
    })
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('form should be submitted with blank required fields if handler is bound to "ajax:aborted:required" event that returns false', 1, function() {
  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .bindNative('ajax:beforeSend', function() {
      ok(true, 'ajax:beforeSend should run')
    })
    .bindNative('ajax:aborted:required', function() {
      return false
    })
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('disabled fields should not be included in blank required check', 2, function() {
  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required" disabled="disabled">'))
    .append($('<textarea name="user_bio" required="required" disabled="disabled"></textarea>'))
    .bindNative('ajax:beforeSend', function() {
      ok(true, 'ajax:beforeSend should run')
    })
    .bindNative('ajax:aborted:required', function() {
      ok(false, 'ajax:aborted:required should not run')
    })

  submit()
})

asyncTest('form should be submitted with blank required fields if it has the "novalidate" attribute', 2, function() {
  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .attr('novalidate', 'novalidate')
    .bindNative('ajax:beforeSend', function() {
      ok(true, 'ajax:beforeSend should run')
    })
    .bindNative('ajax:aborted:required', function() {
      ok(false, 'ajax:aborted:required should not run')
    })

  submit()
})

asyncTest('form should be submitted with blank required fields if the button has the "formnovalidate" attribute', 2, function() {
  var submit_button = $('<input type="submit" formnovalidate>')
  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .append(submit_button)
    .bindNative('ajax:beforeSend', function() {
      ok(true, 'ajax:beforeSend should run')
    })
    .bindNative('ajax:aborted:required', function() {
      ok(false, 'ajax:aborted:required should not run')
    })

  submit_with_button(submit_button)
})

asyncTest('blank required form input for non-remote form with "novalidate" attribute should not abort normal submission', 1, function() {
  $(document).bind('iframe:loading', function() {
    ok(true, 'form should get submitted')
  })

  var form = $('form[data-remote]')
    .append($('<input type="text" name="user_name" required="required">'))
    .removeAttr('data-remote')
    .attr('novalidate', 'novalidate')
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('unchecked required checkbox should abort form submission', 1, function() {
  var form = $('form[data-remote]')
    .append($('<input type="checkbox" name="agree" required="required">'))
    .removeAttr('data-remote')
    .bindNative('ujs:everythingStopped', function() {
      ok(true, 'ujs:everythingStopped should run')
    })
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('unchecked required radio should abort form submission', 3, function() {
  var form = $('form[data-remote]')
    .append($('<input type="radio" name="yes_no_none" required="required" value=1>'))
    .append($('<input type="radio" name="yes_no_none" required="required" value=2>'))
    .removeAttr('data-remote')
    .bindNative('ujs:everythingStopped', function() {
      ok(true, 'ujs:everythingStopped should run')
    })
    .bindNative('ajax:aborted:required', function(e, data) {
      data = $(data)
      equal(data.length, 2, 'blankRequiredInputs should include both radios')
      ok(data.first().is('input[type=radio][value=1]'), 'blankRequiredInputs[0] should be the first radio')
    })
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('required radio should only require one to be checked', 1, function() {
  $(document).bind('iframe:loading', function() {
    ok(true, 'form should get submitted')
  })

  var form = $('form[data-remote]')
    .append($('<input type="radio" name="yes_no" required="required" value=1 id="checkme">'))
    .append($('<input type="radio" name="yes_no" required="required" value=2>'))
    .removeAttr('data-remote')
    .bindNative('ujs:everythingStopped', function() {
      ok(false, 'ujs:everythingStopped should not run')
    })
    .find('#checkme').prop('checked', true)
    .end()
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

asyncTest('required radio should only require one to be checked if not all radios are required', 1, function() {
  $(document).bind('iframe:loading', function() {
    ok(true, 'form should get submitted')
  })

  var form = $('form[data-remote]')
    // Check the radio that is not required
    .append($('<input type="radio" name="yes_no_maybe" value=1 >'))
    // Check the radio that is not required
    .append($('<input type="radio" name="yes_no_maybe" value=2 id="checkme">'))
    // Only one needs to be required
    .append($('<input type="radio" name="yes_no_maybe" required="required" value=3>'))
    .removeAttr('data-remote')
    .bindNative('ujs:everythingStopped', function() {
      ok(false, 'ujs:everythingStopped should not run')
    })
    .find('#checkme').prop('checked', true)
    .end()
    .triggerNative('submit')

  setTimeout(function() {
    start()
  }, 13)
})

function skipIt() {
  // This test cannot work due to the security feature in browsers which makes the value
  // attribute of file input fields readonly, so it cannot be set with default value.
  // This is what the test would look like though if browsers let us automate this test.
  asyncTest('non-blank file form input field should abort remote request, but submit normally', 5, function() {
    var form = $('form[data-remote]')
          .append($('<input type="file" name="attachment" value="default.png">'))
          .bindNative('ajax:beforeSend', function() {
            ok(false, 'ajax:beforeSend should not run')
          })
          .bind('iframe:loading', function() {
            ok(true, 'form should get submitted')
          })
          .bindNative('ajax:aborted:file', function(e, data) {
            ok(data.length == 1, 'ajax:aborted:file event is passed all non-blank file inputs (jQuery objects)')
            ok(data.first().is('input[name="attachment"]'), 'ajax:aborted:file adds non-blank file input to data')
            ok(true, 'ajax:aborted:file event should run')
          })
          .triggerNative('submit')

    setTimeout(function() {
      form.find('input[type="file"]').val('')
      form.unbind('ajax:beforeSend')
      submit()
    }, 13)
  })

  asyncTest('file form input field should not abort remote request if file form input does not have a name attribute', 5, function() {
    var form = $('form[data-remote]')
          .append($('<input type="file" value="default.png">'))
          .bindNative('ajax:beforeSend', function() {
            ok(true, 'ajax:beforeSend should run')
          })
          .bind('iframe:loading', function() {
            ok(true, 'form should get submitted')
          })
          .bindNative('ajax:aborted:file', function(e, data) {
            ok(false, 'ajax:aborted:file should not run')
          })
          .triggerNative('submit')

    setTimeout(function() {
      form.find('input[type="file"]').val('')
      form.unbind('ajax:beforeSend')
      submit()
    }, 13)
  })

  asyncTest('blank file input field should abort request entirely if handler bound to "ajax:aborted:file" event that returns false', 1, function() {
    var form = $('form[data-remote]')
          .append($('<input type="file" name="attachment" value="default.png">'))
          .bindNative('ajax:beforeSend', function() {
            ok(false, 'ajax:beforeSend should not run')
          })
          .bind('iframe:loading', function() {
            ok(false, 'form should not get submitted')
          })
          .bindNative('ajax:aborted:file', function() {
            return false
          })
          .triggerNative('submit')

    setTimeout(function() {
      form.find('input[type="file"]').val('')
      form.unbind('ajax:beforeSend')
      submit()
    }, 13)
  })
}

asyncTest('"ajax:beforeSend" can be observed and stopped with event delegation', 1, function() {
  $(document).delegate('form[data-remote]', 'ajax:beforeSend', function() {
    ok(true, 'ajax:beforeSend observed with event delegation')
    return false
  })

  submit(function(form) {
    form.unbind('ajax:send').bindNative('ajax:send', function() {
      ok(false, 'ajax:send should not run')
    })
    form.unbind('ajax:complete').bindNative('ajax:complete', function() {
      ok(false, 'ajax:complete should not run')
    })
    $(document).bindNative('ajaxStop', function() {
      start()
    })
  })
})

asyncTest('"ajax:beforeSend", "ajax:send", "ajax:success" and "ajax:complete" are triggered', 9, function() {
  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      ok(xhr.setRequestHeader, 'first argument to "ajax:beforeSend" should be an XHR object')
      equal(settings.url, '/echo', 'second argument to "ajax:beforeSend" should be a settings object')
    })
    form.bindNative('ajax:send', function(e, xhr) {
      ok(xhr.abort, 'first argument to "ajax:send" should be an XHR object')
    })
    form.bindNative('ajax:success', function(e, data, status, xhr) {
      ok(data.REQUEST_METHOD, 'first argument to ajax:success should be a data object')
      equal(status, 'OK', 'second argument to ajax:success should be a status string')
      ok(xhr.getResponseHeader, 'third argument to "ajax:success" should be an XHR object')
    })
    form.bindNative('ajax:complete', function(e, xhr, status) {
      ok(xhr.getResponseHeader, 'first argument to "ajax:complete" should be an XHR object')
      equal(status, 'OK', 'second argument to ajax:complete should be a status string')
    })
  })
})

if(window.phantom !== undefined) {
  asyncTest('"ajax:beforeSend", "ajax:send", "ajax:error" and "ajax:complete" are triggered on error', 7, function() {
    submit(function(form) {
      form.attr('action', '/error')
      form.bindNative('ajax:beforeSend', function(arg) { ok(true, 'ajax:beforeSend') })
      form.bindNative('ajax:send', function(arg) { ok(true, 'ajax:send') })
      form.bindNative('ajax:error', function(e, xhr, status, error) {
        ok(xhr.getResponseHeader, 'first argument to "ajax:error" should be an XHR object')
        equal(status, 'error', 'second argument to ajax:error should be a status string')
        // Firefox 8 returns "Forbidden " with trailing space
        equal($.trim(error), 'Forbidden', 'third argument to ajax:error should be an HTTP status response')
        // Opera returns "0" for HTTP code
        equal(xhr.status, window.opera ? 0 : 403, 'status code should be 403')
      })
    })
  })
}

// IF THIS TEST IS FAILING, TRY INCREASING THE TIMEOUT AT THE BOTTOM TO > 100
asyncTest('binding to ajax callbacks via .delegate() triggers handlers properly', 4, function() {
  $(document)
    .delegate('form[data-remote]', 'ajax:beforeSend', function() {
      ok(true, 'ajax:beforeSend handler is triggered')
    })
    .delegate('form[data-remote]', 'ajax:send', function() {
      ok(true, 'ajax:send handler is triggered')
    })
    .delegate('form[data-remote]', 'ajax:complete', function() {
      ok(true, 'ajax:complete handler is triggered')
    })
    .delegate('form[data-remote]', 'ajax:success', function() {
      ok(true, 'ajax:success handler is triggered')
    })
  $('form[data-remote]').triggerNative('submit')

  setTimeout(function() {
    start()
  }, 63)
})

asyncTest('binding to ajax:send event to call jquery methods on ajax object', 2, function() {
  $('form[data-remote]')
    .bindNative('ajax:send', function(e, xhr) {
      ok(true, 'event should fire')
      equal(typeof(xhr.abort), 'function', 'event should pass jqXHR object')
      xhr.abort()
    })
    .triggerNative('submit')

  setTimeout(function() { start() }, 35)
})

})()
