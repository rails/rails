import $ from 'jquery'

QUnit.module('data-disable-with', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<form />', {
      action: '/echo',
      'data-remote': 'true',
      method: 'post'
    }))
      .find('form')
      .append($('<input type="text" data-disable-with="processing ..." name="user_name" value="john" />'))

    $('#qunit-fixture').append($('<form />', {
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
  const done = assert.async()

  var form = $('form[data-remote]'), input = form.find('input[type=text]')

  assert.enabledState(input, 'john')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.enabledState(input, 'john')
      assert.equal(data.params.user_name, 'john')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  assert.disabledState(input, 'processing ...')
})

QUnit.test('blank form input field with "data-disable-with" attribute', function(assert) {
  const done = assert.async()

  var form = $('form[data-remote]'), input = form.find('input[type=text]')

  input.val('')
  assert.enabledState(input, '')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.enabledState(input, '')
      assert.equal(data.params.user_name, '')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  assert.disabledState(input, 'processing ...')
})

QUnit.test('form button with "data-disable-with" attribute', function(assert) {
  const done = assert.async()

  var form = $('form[data-remote]'), button = $('<button data-disable-with="submitting ..." name="submit2">Submit</button>')
  form.append(button)

  assert.enabledState(button, 'Submit')

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.enabledState(button, 'Submit')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  assert.disabledState(button, 'submitting ...')
})

QUnit.test('a[data-remote][data-disable-with] within a form disables and re-enables', function(assert) {
  const done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])'),
      link = $('<a data-remote="true" data-disable-with="clicking...">Click me</a>')
  form.append(link)

  assert.enabledState(link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      assert.disabledState(link, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        assert.enabledState(link, 'Click me')
        link.remove()
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('form input[type=submit][data-disable-with] disables', function(assert) {
  const done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])'), input = form.find('input[type=submit]')

  assert.enabledState(input, 'Submit')

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      assert.disabledState(input, 'submitting ...')
      done()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    assert.disabledState(input, 'submitting ...')
  }, 30)
})

QUnit.test('form input[type=submit][data-disable-with] re-enables when `pageshow` event is triggered', function(assert) {
  var form = $('#qunit-fixture form:not([data-remote])'), input = form.find('input[type=submit]')

  assert.enabledState(input, 'Submit')

  // Emulate the disabled state without submitting the form at all, what is the
  // state after going back on firefox after submitting a form.
  //
  // See https://github.com/rails/jquery-ujs/issues/357
  $.rails.disableElement(form[0])

  assert.disabledState(input, 'submitting ...')

  $(window).triggerNative('pageshow')

  assert.enabledState(input, 'Submit')
})

QUnit.test('form[data-remote] input[type=submit][data-disable-with] is replaced in ajax callback', function(assert) {
  const done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'),
      origFormContents = form.html()

  form.bindNative('ajax:success', function() {
    form.html(origFormContents)

    setTimeout(function() {
      var input = form.find('input[type=submit]')
      assert.enabledState(input, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form[data-remote] input[data-disable-with] is replaced with disabled field in ajax callback', function(assert) {
  const done = assert.async()

  var form = $('#qunit-fixture form:not([data-remote])').attr('data-remote', 'true'),
      input = form.find('input[type=submit]'),
      newDisabledInput = input.clone().attr('disabled', 'disabled')

  form.bindNative('ajax:success', function() {
    input.replaceWith(newDisabledInput)

    setTimeout(function() {
      assert.enabledState(newDisabledInput, 'Submit')
      done()
    }, 30)
  }).triggerNative('submit')
})

QUnit.test('form input[type=submit][data-disable-with] using "form" attribute disables', function(assert) {
  var form = $('#not_remote'), input = $('input[form=not_remote]')
  assert.enabledState(input, 'Form Attr Submit')
  const done = assert.async()

  $(document).bind('iframe:loaded', function(e, data) {
    setTimeout(function() {
      assert.disabledState(input, 'form attr submitting')
      done()
    }, 30)
  })
  form.triggerNative('submit')

  setTimeout(function() {
    assert.disabledState(input, 'form attr submitting')
  }, 30)

})

QUnit.test('form[data-remote] textarea[data-disable-with] attribute', function(assert) {
  const done = assert.async()

  var form = $('form[data-remote]'),
      textarea = $('<textarea data-disable-with="processing ..." name="user_bio">born, lived, died.</textarea>').appendTo(form)

  form.bindNative('ajax:success', function(e, data) {
    setTimeout(function() {
      assert.equal(data.params.user_bio, 'born, lived, died.')
      done()
    }, 13)
  })
  form.triggerNative('submit')

  assert.disabledState(textarea, 'processing ...')
})

QUnit.test('a[data-disable-with] disables', function(assert) {
  const done = assert.async()

  var link = $('a[data-disable-with]')

  assert.enabledState(link, 'Click me')

  link.triggerNative('click')
  assert.disabledState(link, 'clicking...')
  done()
})

QUnit.test('a[data-disable-with] re-enables when `pageshow` event is triggered', function(assert) {
  var link = $('a[data-disable-with]')

  assert.enabledState(link, 'Click me')

  link.triggerNative('click')
  assert.disabledState(link, 'clicking...')

  $(window).triggerNative('pageshow')
  assert.enabledState(link, 'Click me')
})

QUnit.test('a[data-remote][data-disable-with] disables and re-enables', function(assert) {
  const done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)
  assert.enabledState(link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      assert.disabledState(link, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        assert.enabledState(link, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:before` event is cancelled', function(assert) {
  const done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)

  assert.enabledState(link, 'Click me')

  link
    .bindNative('ajax:before', function(e) {
      assert.disabledState(link, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.enabledState(link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  const done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true)

  assert.enabledState(link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function(e) {
      assert.disabledState(link, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.enabledState(link, 'Click me')
    done()
  }, 30)
})

QUnit.test('a[data-remote][data-disable-with] re-enables when `ajax:error` event is triggered', function(assert) {
  const done = assert.async()

  var link = $('a[data-disable-with]').attr('data-remote', true).attr('href', '/error')

  assert.enabledState(link, 'Click me')

  link
    .bindNative('ajax:beforeSend', function() {
      assert.disabledState(link, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout(function() {
        assert.enabledState(link, 'Click me')
        done()
      }, 30)
    })
    .triggerNative('click')
})

QUnit.test('form[data-remote] input|button|textarea[data-disable-with] does not disable when `ajax:beforeSend` event is cancelled', function(assert) {
  var form = $('form[data-remote]'),
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

  assert.enabledState(input, 'john')
  assert.enabledState(button, 'Submit')
  assert.enabledState(textarea, 'born, lived, died.')
  assert.enabledState(submit, 'Submit')
})

QUnit.test('ctrl-clicking on a link does not disable the link', function(assert) {
  var link = $('a[data-disable-with]')

  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { metaKey: true })
  assert.enabledState(link, 'Click me')
})

QUnit.test('right/mouse-wheel-clicking on a link does not disable the link', function(assert) {
  var link = $('a[data-disable-with]')

  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { button: 1 })
  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { button: 1 })
  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { button: 2 })
  assert.enabledState(link, 'Click me')

  link.triggerNative('click', { button: 2 })
  assert.enabledState(link, 'Click me')
})

QUnit.test('button[data-remote][data-disable-with] disables and re-enables', function(assert) {
  const done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  assert.enabledState(button, 'Click me')

  button
    .bindNative('ajax:send', function() {
      assert.disabledState(button, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout( function() {
        assert.enabledState(button, 'Click me')
        done()
      }, 15)
    })
    .triggerNative('click')
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:before` event is cancelled', function(assert) {
  const done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  assert.enabledState(button, 'Click me')

  button
    .bindNative('ajax:before', function(e) {
      assert.disabledState(button, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.enabledState(button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:beforeSend` event is cancelled', function(assert) {
  const done = assert.async()

  var button = $('button[data-remote][data-disable-with]')

  assert.enabledState(button, 'Click me')

  button
    .bindNative('ajax:beforeSend', function(e) {
      assert.disabledState(button, 'clicking...')
      e.preventDefault()
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.enabledState(button, 'Click me')
    done()
  }, 30)
})

QUnit.test('button[data-remote][data-disable-with] re-enables when `ajax:error` event is triggered', function(assert) {
  const done = assert.async()

  var button = $('a[data-disable-with]').attr('data-remote', true).attr('href', '/error')

  assert.enabledState(button, 'Click me')
  button
    .bindNative('ajax:send', function() {
      assert.disabledState(button, 'clicking...')
    })
    .bindNative('ajax:complete', function() {
      setTimeout(function() {
        assert.enabledState(button, 'Click me')
        done()
      }, 30)
    })
    .triggerNative('click')
})
