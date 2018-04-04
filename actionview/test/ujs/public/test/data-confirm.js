module('data-confirm', {
  setup: function() {
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
  teardown: function() {
    window.confirm = this.windowConfirm
  }
})

asyncTest('clicking on a link with data-confirm attribute. Confirm yes.', 6, function() {
  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked('ajax:success')
      App.assertRequestPath(data, '/echo')
      App.assertGetRequest(data)

      equal(message, 'Are you absolutely sure?')
      start()
    })
    .triggerNative('click')
})

asyncTest('clicking on a button with data-confirm attribute. Confirm yes.', 6, function() {
  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked('ajax:success')
      App.assertRequestPath(data, '/echo')
      App.assertGetRequest(data)

      equal(message, 'Are you absolutely sure?')
      start()
    })
    .triggerNative('click')
})

asyncTest('clicking on a link with data-confirm attribute. Confirm No.', 3, function() {
  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    equal(message, 'Are you absolutely sure?')
    start()
  }, 50)
})

asyncTest('clicking on a button with data-confirm attribute. Confirm No.', 3, function() {
  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    equal(message, 'Are you absolutely sure?')
    start()
  }, 50)
})

asyncTest('clicking on a button with data-confirm attribute. Confirm error.', 3, function() {
  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; throw 'some random error' }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    equal(message, 'Are you absolutely sure?')
    start()
  }, 50)
})

asyncTest('clicking on a submit button with form and data-confirm attributes. Confirm No.', 3, function() {
  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('input[type=submit][form]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == false, 'confirm:complete passes in confirm answer (false)')
    })
    .bindNative('ajax:beforeSend', function(e, data, status, xhr) {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    equal(message, 'Are you absolutely sure?')
    start()
  }, 50)
})

asyncTest('binding to confirm event of a link and returning false', 1, function() {
  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    ok(false, 'confirm dialog should not be called')
  }

  $('a[data-confirm]')
    .bindNative('confirm', function() {
      App.assertCallbackInvoked('confirm')
      return false
    })
    .bindNative('confirm:complete', function() {
      App.assertCallbackNotInvoked('confirm:complete')
    })
    .triggerNative('click')

  setTimeout(function() {
    start()
  }, 50)
})

asyncTest('binding to confirm event of a button and returning false', 1, function() {
  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    ok(false, 'confirm dialog should not be called')
  }

  $('button[data-confirm]')
    .bindNative('confirm', function() {
      App.assertCallbackInvoked('confirm')
      return false
    })
    .bindNative('confirm:complete', function() {
      App.assertCallbackNotInvoked('confirm:complete')
    })
    .triggerNative('click')

  setTimeout(function() {
    start()
  }, 50)
})

asyncTest('binding to confirm:complete event of a link and returning false', 2, function() {
  // auto-confirm:
  window.confirm = function(msg) {
    ok(true, 'confirm dialog should be called')
    return true
  }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function() {
      App.assertCallbackInvoked('confirm:complete')
      return false
    })
    .bindNative('ajax:beforeSend', function() {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    start()
  }, 50)
})

asyncTest('binding to confirm:complete event of a button and returning false', 2, function() {
  // auto-confirm:
  window.confirm = function(msg) {
    ok(true, 'confirm dialog should be called')
    return true
  }

  $('button[data-confirm]')
    .bindNative('confirm:complete', function() {
      App.assertCallbackInvoked('confirm:complete')
      return false
    })
    .bindNative('ajax:beforeSend', function() {
      App.assertCallbackNotInvoked('ajax:beforeSend')
    })
    .triggerNative('click')

  setTimeout(function() {
    start()
  }, 50)
})

asyncTest('a button inside a form only confirms once', 1, function() {
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

  $('form > button[data-confirm]').triggerNative('click')

  ok(confirmations === 1, 'confirmation counter should be 1, but it was ' + confirmations)
  start()
})

asyncTest('clicking on the children of a link should also trigger a confirm', 6, function() {
  var message
  // auto-confirm:
  window.confirm = function(msg) { message = msg; return true }

  $('a[data-confirm]')
    .html('<strong>Click me</strong>')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked('ajax:success')
      App.assertRequestPath(data, '/echo')
      App.assertGetRequest(data)

      equal(message, 'Are you absolutely sure?')
      start()
    })
    .find('strong')
    .triggerNative('click')
})

asyncTest('clicking on the children of a disabled button should not trigger a confirm.', 1, function() {
  var message
  // auto-decline:
  window.confirm = function(msg) { message = msg; return false }

  $('button[data-confirm][disabled]')
    .html('<strong>Click me</strong>')
    .bindNative('confirm', function() {
      App.assertCallbackNotInvoked('confirm')
    })
    .find('strong')
    .bindNative('click', function() {
      App.assertCallbackInvoked('click')
    })
    .triggerNative('click')

  setTimeout(function() {
    start()
  }, 50)
})

asyncTest('clicking on a link with data-confirm attribute with custom confirm handler. Confirm yes.', 7, function() {
  var message, element
  // redefine confirm function so we can make sure it's not called
  window.confirm = function(msg) {
    ok(false, 'confirm dialog should not be called')
  }
  // custom auto-confirm:
  Rails.confirm = function(msg, elem) { message = msg; element = elem; return true }

  $('a[data-confirm]')
    .bindNative('confirm:complete', function(e, data) {
      App.assertCallbackInvoked('confirm:complete')
      ok(data == true, 'confirm:complete passes in confirm answer (true)')
    })
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertCallbackInvoked('ajax:success')
      App.assertRequestPath(data, '/echo')
      App.assertGetRequest(data)

      equal(message, 'Are you absolutely sure?')
      equal(element, $('a[data-confirm]').get(0))
      start()
    })
    .triggerNative('click')
})
