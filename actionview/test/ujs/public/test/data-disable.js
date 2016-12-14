module('data-disable', {
  setup: function() {
    $('#qunit-fixture').append($('<form />', {
      action: '/echo',
      'data-remote': 'true',
      method: 'post'
    }))
      .find('form')
      .append($('<input type="text" data-disable name="user_name" value="john" />'))

    $('#qunit-fixture').append($('<form />', {
      action: '/echo',
      method: 'post'
    }))
      .find('form:last')
      // WEEIRDD: the form won't submit to an iframe if the button is name="submit" (??!)
      .append($('<input type="submit" data-disable name="submit2" value="Submit" />'))

    $('#qunit-fixture').append($('<a />', {
      text: 'Click me',
      href: '/echo',
      'data-disable': 'true'
    }))

    $('#qunit-fixture').append($('<button />', {
      text: 'Click me',
      'data-remote': true,
      'data-url': '/echo',
      'data-disable': 'true'
    }))
  },
  teardown: function() {
    $(document).unbind('iframe:loaded')
  }
})

asyncTest('form input field with "data-disable" attribute', 7, function() {
  var form = $('form[data-remote]'), input = form.find('input[type=text]')

  App.checkEnabledState(input, 'john')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(input, 'john')
      equal(data.params.user_name, 'john')
      start()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(input, 'john')
})

asyncTest('form button with "data-disable" attribute', 7, function() {
  var form = $('form[data-remote]'), button = $('<button data-disable name="submit2">Submit</button>')
  form.append(button)

  App.checkEnabledState(button, 'Submit')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(button, 'Submit')
      start()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(button, 'Submit')
  equal(button.data('ujs:enable-with'), undefined)
})

asyncTest('form input[type=submit][data-disable] disables', 6, function() {
  var form = $('form:not([data-remote])'), input = form.find('input[type=submit]')

  App.checkEnabledState(input, 'Submit')

  // WEEIRDD: attaching this handler makes the test work in IE7
  $(document).bind('iframe:loading', function(e, f) {})

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      App.checkDisabledState(input, 'Submit')
      start()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    App.checkDisabledState(input, 'Submit')
  }, 30)
})

asyncTest('form[data-remote] input[type=submit][data-disable] is replaced in ajax callback', 2, function() {
  var form = $('form:not([data-remote])').attr('data-remote', 'true'), origFormContents = form.html()

  form.bindNative('ajax:success', function() {
    form.html(origFormContents)

    setTimeout(function() {
      var input = form.find('input[type=submit]')
      App.checkEnabledState(input, 'Submit')
      start()
    }, 30)
  }).triggerNative('submit')
})

asyncTest('form[data-remote] input[data-disable] is replaced with disabled field in ajax callback', 2, function() {
  var form = $('form:not([data-remote])').attr('data-remote', 'true'), input = form.find('input[type=submit]'),
      newDisabledInput = input.clone().attr('disabled', 'disabled')

  form.bindNative('ajax:success', function() {
    input.replaceWith(newDisabledInput)

    setTimeout(function() {
      App.checkEnabledState(newDisabledInput, 'Submit')
      start()
    }, 30)
  }).triggerNative('submit')
})

asyncTest('form[data-remote] textarea[data-disable] attribute', 3, function() {
  var form = $('form[data-remote]'),
      textarea = $('<textarea data-disable name="user_bio">born, lived, died.</textarea>').appendTo(form)

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      equal(data.params.user_bio, 'born, lived, died.')
      start()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(textarea, 'born, lived, died.')
})

asyncTest('a[data-disable] disables', 5, function() {
  var link = $('a[data-disable]')

  App.checkEnabledState(link, 'Click me')

  link.triggerNative('click')
  App.checkDisabledState(link, 'Click me')
  equal(link.data('ujs:enable-with'), undefined)
  start()
})

asyncTest('a[data-remote][data-disable] disables and re-enables', 6, function() {
  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(link, 'Click me')

  link
    .bindNative('ajax:send', function() {
      App.checkDisabledState(link, 'Click me')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(link, 'Click me')
        start()
      }, 15)
    })
    .triggerNative('click')
})

asyncTest('a[data-remote][data-disable] re-enables when `ajax:before` event is cancelled', 6, function() {
  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(link, 'Click me')

  link
    .bindNative('ajax:before', function() {
      App.checkDisabledState(link, 'Click me')
      return false
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(link, 'Click me')
    start()
  }, 30)
})

asyncTest('a[data-remote][data-disable] re-enables when `ajax:beforeSend` event is cancelled', 6, function() {
  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      App.checkDisabledState(link, 'Click me')
      return false
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(link, 'Click me')
    start()
  }, 30)
})

asyncTest('a[data-remote][data-disable] re-enables when `ajax:error` event is triggered', 6, function() {
  var link = $('a[data-disable]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(link, 'Click me')

  link
    .bindNative('ajax:send', function() {
      App.checkDisabledState(link, 'Click me')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(link, 'Click me')
    start()
  }, 30)
})

asyncTest('form[data-remote] input|button|textarea[data-disable] does not disable when `ajax:beforeSend` event is cancelled', 8, function() {
  var form = $('form[data-remote]'),
      input = form.find('input:text'),
      button = $('<button data-disable="submitting ..." name="submit2">Submit</button>').appendTo(form),
      textarea = $('<textarea data-disable name="user_bio">born, lived, died.</textarea>').appendTo(form),
      submit = $('<input type="submit" data-disable="submitting ..." name="submit2" value="Submit" />').appendTo(form)

  form
    .bindNative('ajax:beforeSend', function() {
      return false
    })
    .triggerNative('submit')

  App.checkEnabledState(input, 'john')
  App.checkEnabledState(button, 'Submit')
  App.checkEnabledState(textarea, 'born, lived, died.')
  App.checkEnabledState(submit, 'Submit')

  start()
})

asyncTest('ctrl-clicking on a link does not disables the link', 6, function() {
  var link = $('a[data-disable]')

  App.checkEnabledState(link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  App.checkEnabledState(link, 'Click me')

  link.triggerNative('click', { ctrlKey: true })
  App.checkEnabledState(link, 'Click me')
  start()
})

asyncTest('button[data-remote][data-disable] disables and re-enables', 6, function() {
  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(button, 'Click me')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(button, 'Click me')
        start()
      }, 15)
    })
    .triggerNative('click')
})

asyncTest('button[data-remote][data-disable] re-enables when `ajax:before` event is cancelled', 6, function() {
  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(button, 'Click me')

  button
    .bindNative('ajax:before', function() {
      App.checkDisabledState(button, 'Click me')
      return false
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(button, 'Click me')
    start()
  }, 30)
})

asyncTest('button[data-remote][data-disable] re-enables when `ajax:beforeSend` event is cancelled', 6, function() {
  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(button, 'Click me')

  button
    .bindNative('ajax:beforeSend', function() {
      App.checkDisabledState(button, 'Click me')
      return false
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(button, 'Click me')
    start()
  }, 30)
})

asyncTest('button[data-remote][data-disable] re-enables when `ajax:error` event is triggered', 6, function() {
  var button = $('a[data-disable]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(button, 'Click me')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(button, 'Click me')
    start()
  }, 30)
})
