QUnit.module('data-disable-with', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<form />', {
      class: 'rails-ujs-target',
      action: '/echo',
      'data-remote': 'true',
      method: 'post'
    }))
      .find('form.rails-ujs-target')
      .append($('<input type="text" data-disable-with="processing ..." name="user_name" value="john" />'))

    $('#qunit-fixture').append($('<form />', {
      class: 'rails-ujs-target',
      action: '/echo',
      method: 'post',
      id: 'not_remote'
    }))
      .find('form:last')
      // WEEIRDD: the form won't submit to an iframe if the button is name="submit" (??!)
      .append($('<input type="submit" data-disable-with="submitting ..." name="submit2" value="Submit" />'))

    $('#qunit-fixture').append($('<a />', {
      text: 'Click me',
      href: '/echo',
      'data-disable-with': 'clicking...'
    }))

    $('#qunit-fixture').append($('<input />', {
      type: 'submit',
      form: 'not_remote',
      'data-disable-with': 'form attr submitting',
      name: 'submit3',
      value: 'Form Attr Submit'
    }))

    $('#qunit-fixture').append($('<button />', {
      text: 'Click me',
      'data-remote': true,
      'data-url': '/echo',
      'data-disable-with': 'clicking...'
    }))
  },
  afterEach: function() {
    $(document).unbind('iframe:loaded')
  }
})

QUnit.test('form input field with "data-disable-with" attribute', function(assert) {
  assert.expect(7)
  var done = assert.async()

  var form = $('form.rails-ujs-target[data-remote]'), input = form.find('input[type=text]')

  App.checkEnabledState(assert, input, 'john')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(assert, input, 'john')
      assert.equal(data.params.user_name, 'john')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, input, 'processing ...')
})

QUnit.test('blank form input field with "data-disable-with" attribute', function(assert) {
  assert.expect(7)
  var done = assert.async()

  var form = $('form.rails-ujs-target[data-remote]'), input = form.find('input[type=text]')

  input.val('')
  App.checkEnabledState(assert, input, '')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(assert, input, '')
      assert.equal(data.params.user_name, '')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, input, 'processing ...')
})

QUnit.test('form button with "data-disable-with" attribute', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var form = $('form.rails-ujs-target[data-remote]'), button = $('<button data-disable-with="submitting ..." name="submit2">Submit</button>')
  form.append(button)

  App.checkEnabledState(assert, button, 'Submit')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      App.checkEnabledState(assert, button, 'Submit')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, button, 'submitting ...')
})

QUnit.test('a[data-remote][data-disable-with] within a form disables and re-enables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var form = $('form.rails-ujs-target:not([data-remote])'),
      link = $('<a data-remote="true" data-disable-with="clicking...">Click me</a>')
  form.append(link)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      App.checkDisabledState(assert, link, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(assert, link, 'Click me')
        link.remove()
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('form input[type=submit][data-disable-with] disables', function(assert) {
  assert.expect(6)
  var done = assert.async(2)

  var form = $('form.rails-ujs-target:not([data-remote])'), input = form.find('input[type=submit]')

  App.checkEnabledState(assert, input, 'Submit')

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      App.checkDisabledState(assert, input, 'submitting ...')
      done()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    App.checkDisabledState(assert, input, 'submitting ...')
    done()
  }, 30)
})

QUnit.test('form input[type=submit][data-disable-with] re-enables when `pageshow` event is triggered', function(assert) {
  var form = $('form.rails-ujs-target:not([data-remote])'), input = form.find('input[type=submit]')

  App.checkEnabledState(assert, input, 'Submit')

  // Emulate the disabled state without submitting the form at all, what is the
  // state after going back on firefox after submitting a form.
  //
  // See https://github.com/rails/jquery-ujs/issues/357
  $.rails.disableElement(form[0])

  App.checkDisabledState(assert, input, 'submitting ...')

  $(window).triggerNative('pageshow')

  App.checkEnabledState(assert, input, 'Submit')
})

QUnit.test('form[data-remote] input[type=submit][data-disable-with] is replaced in ajax callback', function(assert) {
  assert.expect(2)
  var done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'),
      origFormContents = form.html()

  form.bindNative('ajax:success', function() {
    form.html(origFormContents)

    setTimeout(function() {
      var input = form.find('input[type=submit]')
      App.checkEnabledState(assert, input, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form[data-remote] input[data-disable-with] is replaced with disabled field in ajax callback', function(assert) {
  assert.expect(2)
  var done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'),
      input = form.find('input[type=submit]'),
      newDisabledInput = input.clone().attr('disabled', 'disabled')

  form.bindNative('ajax:success', function() {
    input.replaceWith(newDisabledInput)

    setTimeout(function() {
      App.checkEnabledState(assert, newDisabledInput, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form input[type=submit][data-disable-with] using "form" attribute disables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var form = $('#not_remote'), input = $('input[form=not_remote]')
  App.checkEnabledState(assert, input, 'Form Attr Submit')

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      App.checkDisabledState(assert, input, 'form attr submitting')
      done()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    App.checkDisabledState(assert, input, 'form attr submitting')
  }, 30)

})

QUnit.test('form[data-remote] textarea[data-disable-with] attribute', function(assert) {
  assert.expect(3)
  var done = assert.async()

  var form = $('form.rails-ujs-target[data-remote]'),
      textarea = $('<textarea data-disable-with="processing ..." name="user_bio">born, lived, died.</textarea>').appendTo(form)

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.equal(data.params.user_bio, 'born, lived, died.')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  App.checkDisabledState(assert, textarea, 'processing ...')
})

QUnit.test('a[data-disable-with] disables', function(assert) {
  assert.expect(4)
  var done = assert.async()

  var link = $('a[data-disable-with]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click')
  App.checkDisabledState(assert, link, 'clicking...')
  done()
})

QUnit.test('a[data-disable-with] re-enables when `pageshow` event is triggered', function(assert) {
  var link = $('a[data-disable-with]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click')
  App.checkDisabledState(assert, link, 'clicking...')

  $(window).triggerNative('pageshow')
  App.checkEnabledState(assert, link, 'Click me')
})

QUnit.test('a[data-remote][data-disable-with] disables and re-enables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      App.checkDisabledState(assert, link, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(assert, link, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:before` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:before', function(e) {
      App.checkDisabledState(assert, link, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function(e) {
      App.checkDisabledState(assert, link, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:error` event is triggered', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(assert, link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      App.checkDisabledState(assert, link, 'clicking...')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, link, 'Click me')
    done()
  }, 30)
})

QUnit.test('form[data-remote] input|button|textarea[data-disable-with] does not disable when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(8)
  var done = assert.async()

  var form = $('form.rails-ujs-target[data-remote]'),
      input = form.find('input:text'),
      button = $('<button data-disable-with="submitting ..." name="submit2">Submit</button>').appendTo(form),
      textarea = $('<textarea data-disable-with="processing ..." name="user_bio">born, lived, died.</textarea>').appendTo(form),
      submit = $('<input type="submit" data-disable-with="submitting ..." name="submit2" value="Submit" />').appendTo(form)

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

QUnit.test('ctrl-clicking on a link does not disable the link', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var link = $('a[data-disable-with]')

  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  App.checkEnabledState(assert, link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  App.checkEnabledState(assert, link, 'Click me')
  done()
})

QUnit.test('right/mouse-wheel-clicking on a link does not disable the link', function(assert) {
  assert.expect(10)
  var done = assert.async()

  var link = $('a[data-disable-with]')

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

QUnit.test('button[data-remote][data-disable-with] disables and re-enables', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, button, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        App.checkEnabledState(assert, button, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:before` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:before', function(e) {
      App.checkDisabledState(assert, button, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:beforeSend', function(e) {
      App.checkDisabledState(assert, button, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:error` event is triggered', function(assert) {
  assert.expect(6)
  var done = assert.async()

  var button = $('a[data-disable-with]').attr('data-remote', true).attr('href', '/error')

  App.checkEnabledState(assert, button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      App.checkDisabledState(assert, button, 'clicking...')
    })
    .triggerNative('click')

  setTimeout(function() {
    App.checkEnabledState(assert, button, 'Click me')
    done()
  }, 30)
})
