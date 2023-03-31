import $ from 'jquery'

QUnit.module('data-confirm', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<a />', {
      href: '/echo',
      'data-remote': 'true',
      'data-confirm': 'Are you absolutely sure?',
      text: 'my social security number'
    }))

    $('#qunit-fixture').append($('<button />', {
      'data-url': '/echo',
      'data-remote': 'true',
      'data-confirm': 'Are you absolutely sure?',
      text: 'Click me'
    }))

    $('#qunit-fixture').append($('<form />', {
      id: 'confirm',
      action: '/echo',
      'data-remote': 'true'
    }))

    $('#qunit-fixture').append($('<input />', {
      type: 'submit',
      form: 'confirm',
      'data-confirm': 'Are you absolutely sure?'
    }))

    $('#qunit-fixture').append($('<button />', {
      type: 'submit',
      form: 'confirm',
      disabled: 'disabled',
      'data-confirm': 'Are you absolutely sure?'
    }))

    this.windowConfirm = window.confirm
  },
  afterEach: function() {
    window.confirm = this.windowConfirm
  }
})

QUnit.test('clicking on a link with data-confirm attribute. Confirm yes.', function(assert) {
  const done = assert.async()

  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.callbackInvoked('ajax:success')
      assert.requestPath(data, '/echo')
      assert.getRequest(data)

      assert.equal(message, 'Are you absolutely sure?')
      done()
    })
    .triggerNative('click')
})

QUnit.test('clicking on a button with data-confirm attribute. Confirm yes.', function(assert) {
  const done = assert.async()

  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.callbackInvoked('ajax:success')
      assert.requestPath(data, '/echo')
      assert.getRequest(data)

      assert.equal(message, 'Are you absolutely sure?')
      done()
    })
    .triggerNative('click')
})

QUnit.test('clicking on a link with data-confirm attribute. Confirm No.', function(assert) {
  const done = assert.async()

  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.equal(message, 'Are you absolutely sure?')
    done()
  }, 50)
})

QUnit.test('clicking on a button with data-confirm attribute. Confirm No.', function(assert) {
  const done = assert.async()

  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.equal(message, 'Are you absolutely sure?')
    done()
  }, 50)
})

QUnit.test('clicking on a button with data-confirm attribute. Confirm error.', function(assert) {
  const done = assert.async()

  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; throw 'some random error' }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.equal(message, 'Are you absolutely sure?')
    done()
  }, 50)
})

QUnit.test('clicking on a submit button with form and data-confirm attributes. Confirm No.', function(assert) {
  const done = assert.async()

  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('#qunit-fixture input[type=submit][form]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    assert.equal(message, 'Are you absolutely sure?')
    done()
  }, 50)
})

QUnit.test('binding to confirm event of a link and returning false', function(assert) {
  const done = assert.async()

  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    assert.ok(false, 'confirm dialog should not be called')
  }

  $('a[data-confirm]')
    .bindNative('confirm', function(e) {
      assert.callbackInvoked('confirm')
      e.preventDefault()
    })
    .bindNative('confirm:complete', function() {
      assert.callbackNotInvoked('confirm:complete')
    })
    .triggerNative('click')

  setTimeout(function() {
    done()
  }, 50)
})

QUnit.test('binding to confirm event of a button and returning false', function(assert) {
  const done = assert.async()

  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    assert.ok(false, 'confirm dialog should not be called')
  }

  $('button[data-confirm]')
    .bindNative('confirm', function(e) {
      assert.callbackInvoked('confirm')
      e.preventDefault()
    })
    .bindNative('confirm:complete', function() {
      assert.callbackNotInvoked('confirm:complete')
    })
    .triggerNative('click')

  setTimeout(function() {
    done()
  }, 50)
})

QUnit.test('binding to confirm:complete event of a link and returning false', function(assert) {
  const done = assert.async()

  // auto-confirm:
  window.confirm = function(msg) {
    assert.ok(true, 'confirm dialog should be called')
    return true
  }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e) {
      assert.callbackInvoked('confirm:complete')
      e.preventDefault()
    })
    .bindNative('ajax:beforeSend', function() {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    done()
  }, 50)
})

QUnit.test('binding to confirm:complete event of a button and returning false', function(assert) {
  const done = assert.async()

  // auto-confirm:
  window.confirm = function(msg) {
    assert.ok(true, 'confirm dialog should be called')
    return true
  }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e) {
      assert.callbackInvoked('confirm:complete')
      e.preventDefault()
    })
    .bindNative('ajax:beforeSend', function() {
      assert.callbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    done()
  }, 50)
})

QUnit.test('a button inside a form only confirms once', function(assert) {
  const done = assert.async()

  var confirmations = 0
  window.confirm = function(msg) {
    confirmations++
    return true
  }

  $('#qunit-fixture').append($('<form />').append($('<button />', {
    'data-remote': 'true',
    'data-confirm': 'Are you absolutely sure?',
    text: 'Click me'
  })))

  $('#qunit-fixture form > button[data-confirm]').triggerNative('click')

  assert.ok(confirmations === 1, 'confirmation counter should be 1, but it was ' + confirmations)
  done()
})

QUnit.test('clicking on the children of a link should also trigger a confirm', function(assert) {
  const done = assert.async()

  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('a[data-confirm]')
    .html('<strong>Click me</strong>')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.callbackInvoked('ajax:success')
      assert.requestPath(data, '/echo')
      assert.getRequest(data)

      assert.equal(message, 'Are you absolutely sure?')
      done()
    })
    .find('strong')
    .triggerNative('click')
})

QUnit.test('clicking on the children of a disabled button should not trigger a confirm.', function(assert) {
  const done = assert.async()

  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('button[data-confirm][disabled]')
    .html('<strong>Click me</strong>')
    .bindNative('confirm', function() {
      assert.callbackNotInvoked('confirm')
    })
    .find('strong')
    .bindNative('click', function() {
      assert.callbackInvoked('click')
    })
    .triggerNative('click')

  setTimeout(function() {
    done()
  }, 50)
})

QUnit.test('clicking on a link with data-confirm attribute with custom confirm handler. Confirm yes.', function(assert) {
  const done = assert.async()

  var message, element
  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    assert.ok(false, 'confirm dialog should not be called')
  }
  // custom auto-confirm:
  Rails.confirm = function(msg, elem) { message = msg; element = elem; return true }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      assert.callbackInvoked('confirm:complete')
      assert.ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      assert.callbackInvoked('ajax:success')
      assert.requestPath(data, '/echo')
      assert.getRequest(data)

      assert.equal(message, 'Are you absolutely sure?')
      assert.equal(element, $('a[data-confirm]').get(0))
      done()
    })
    .triggerNative('click')
})
