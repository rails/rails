QUnit.module('data-disable', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<form />', {
      class: 'qunit-target',
      action: '/echo',
      'data-remote': 'true',
      method: 'post'
    }))
      .find('form.qunit-target')
      .append($('<input type="text" data-disable name="user_name" value="john" />'))

    $('#qunit-fixture').append($('<form  />', {
      class: 'qunit-target',
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
  afterEach: function() {
    $(document).unbind('iframe:loaded')
  }
})

QUnit.test('form input field with "data-disable" attribute', function(assert) {
  assert.expect(7)
  var done = assert.async()

  var form = $('form.qunit-target[data-remote]'), input = form.find('input[type=text]')

  App.checkEnabledState(assert, input, 'john')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(assert, input, 'john')
      assert.equal(data.params.user_name, 'john')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, input, 'john')
})

QUnit.test('form button with "data-disable" attribute', function(assert) {
  assert.expect(7)
  var done = assert.async()

  var form = $('form.qunit-target[data-remote]'), button = $('<button data-disable name="submit2">Submit</button>')
  form.append(button)

  App.checkEnabledState(assert, button, 'Submit')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(assert, button, 'Submit')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, button, 'Submit')
  assert.equal(button.data('ujs:enable-with'), undefined)
})

QUnit.test('form input[type=submit][data-disable] disables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var form = $('form.qunit-target:not([data-remote])'), input = form.find('input[type=submit]')

  App.checkEnabledState(assert, input, 'Submit')

  // WEEIRDD: attaching this handler makes the test work in IE7
  $(document).bind('iframe:loading', function(e, f) {})

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      App.checkDisabledState(assert, input, 'Submit')
      done()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    App.checkDisabledState(assert, input, 'Submit')
  }, 30)
})

QUnit.test('form[data-remote] input[type=submit][data-disable] is replaced in ajax callback', function(assert) {
  assert.expect(2)
  var done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'), origFormContents = form.html()

  form.bindNative('ajax:success', function() {
    form.html(origFormContents)

    setTimeout(function() {
      var input = form.find('input[type=submit]')
      App.checkEnabledState(assert, input, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form[data-remote] input[data-disable] is replaced with disabled field in ajax callback', function(assert) {
  assert.expect(2)
  var done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'), input = form.find('input[type=submit]'),
      newDisabledInput = input.clone().attr('disabled', 'disabled')

  form.bindNative('ajax:success', function() {
    input.replaceWith(newDisabledInput)

    setTimeout(function() {
      App.checkEnabledState(assert, newDisabledInput, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form[data-remote] textarea[data-disable] attribute', function(assert) {
  assert.expect(3)
  var done = assert.async()

  var form = $('form.qunit-target[data-remote]'),
      textarea = $('<textarea data-disable name="user_bio">born, lived, died.</textarea>').appendTo(form)

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.equal(data.params.user_bio, 'born, lived, died.')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, textarea, 'born, lived, died.')
})

QUnit.test('a[data-disable] disables', function(assert) {
  assert.expect(5)
  var done = assert.async()

  var link = $('a[data-disable]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click')
  App.checkDisabledState(assert, link, 'Click me')
  assert.equal(link.data('ujs:enable-with'), undefined)
  done()
})

QUnit.test('a[data-remote][data-disable] disables and re-enables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, link, 'Click me')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(assert, link, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('a[data-remote][data-disable] re-enables when `ajax:before` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:before', function(e) {
      App.checkDisabledState(assert, link, 'Click me')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function(e) {
      App.checkDisabledState(assert, link, 'Click me')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable] re-enables when `ajax:error` event is triggered', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, link, 'Click me')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('form[data-remote] input|button|textarea[data-disable] does not disable when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(8)
  var done = assert.async()

  var form = $('form.qunit-target[data-remote]'),
      input = form.find('input:text'),
      button = $('<button data-disable="submitting ..." name="submit2">Submit</button>').appendTo(form),
      textarea = $('<textarea data-disable name="user_bio">born, lived, died.</textarea>').appendTo(form),
      submit = $('<input type="submit" data-disable="submitting ..." name="submit2" value="Submit" />').appendTo(form)

  form
    .bindNative('ajax:beforeSend', function(e) {
      e.preventDefault()
      e.stopPropagation()
    })
    .triggerNative('submit')

  App.checkEnabledState(assert, input, 'john')
  App.checkEnabledState(assert, button, 'Submit')
  App.checkEnabledState(assert, textarea, 'born, lived, died.')
  App.checkEnabledState(assert, submit, 'Submit')

  done()
})

QUnit.test('ctrl-clicking on a link does not disables the link', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { ctrlKey: true })
  App.checkEnabledState(assert, link, 'Click me')
  done()
})

QUnit.test('right/mouse-wheel-clicking on a link does not disable the link', function(assert) {
  assert.expect(10)
  var done = assert.async()

  var link = $('a[data-disable]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { button: 1 })
  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { button: 1 })
  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { button: 2 })
  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { button: 2 })
  App.checkEnabledState(assert, link, 'Click me')
  done()
})

QUnit.test('button[data-remote][data-disable] disables and re-enables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, button, 'Click me')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(assert, button, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('button[data-remote][data-disable] re-enables when `ajax:before` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:before', function(e) {
      App.checkDisabledState(assert, button, 'Click me')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:beforeSend', function(e) {
      App.checkDisabledState(assert, button, 'Click me')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable] re-enables when `ajax:error` event is triggered', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('a[data-disable]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, button, 'Click me')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})

QUnit.test('do not enable elements for XHR redirects', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable]').attr('data-remote', true).attr('href', '/echo?with_xhr_redirect=true')

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, link, 'Click me')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkDisabledState(assert, link, 'Click me')
    done()
  }, 30)
})
