import $ from 'jquery'

QUnit.module('call-remote-callbacks', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<form />', {
      action: '/echo', method: 'get', 'data-remote': 'true'
    }))
  },
  afterEach: function() {
    $(document).undelegate('form[data-remote]', 'ajax:beforeSend')
    $(document).undelegate('form[data-remote]', 'ajax:before')
    $(document).undelegate('form[data-remote]', 'ajax:send')
    $(document).undelegate('form[data-remote]', 'ajax:complete')
    $(document).undelegate('form[data-remote]', 'ajax:success')
    $(document).unbind('iframe:loading')
  }
})

function submit(fn) {
  var form = $('#qunit-fixture form')

  if (fn) fn(form)
  form.triggerNative('submit')
}

QUnit.test('modifying form fields with "ajax:before" sends modified data in request', function(assert) {
  const done = assert.async()

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
      assert.equal(data.params.user_name, 'steve', 'modified field value should have been submitted')
      assert.equal(data.params.other_user_name, 'jonathan', 'added field value should have been submitted')
      assert.equal(data.params.removed_user_name, undefined, 'removed field value should be undefined')
      done()
    })
  })
})

QUnit.test('modifying data("type") with "ajax:before" requests new dataType in request', function(assert) {
  $('form[data-remote]').data('type', 'html')
    .bindNative('ajax:before', function() {
      this.setAttribute('data-type', 'xml')
    })

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      assert.equal(settings.dataType, 'xml', 'modified dataType should have been requested')
    })
  })
})

QUnit.test('setting data("with-credentials",true) with "ajax:before" uses new setting in request', function(assert) {
  $('form[data-remote]').data('with-credentials', false)
    .bindNative('ajax:before', function() {
      this.setAttribute('data-with-credentials', true)
    })

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      assert.equal(settings.withCredentials, true, 'setting modified in ajax:before should have forced withCredentials request')
    })
  })
})

QUnit.test('stopping the "ajax:beforeSend" event aborts the request', function(assert) {
  const done = assert.async()

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e) {
      assert.ok(true, 'aborting request in ajax:beforeSend')
      e.preventDefault()
    })
    form.unbind('ajax:send').bindNative('ajax:send', function() {
      assert.ok(false, 'ajax:send should not run')
    })
    form.bindNative('ajax:error', function(e, response, status, xhr) {
      assert.ok(false, 'ajax:error should not run')
    })
    form.bindNative('ajax:complete', function() {
      assert.ok(false, 'ajax:complete should not run')
    })
  })

  setTimeout(function() { done() }, 13)
})

function skipIt() {
  // This test cannot work due to the security feature in browsers which makes the value
  // attribute of file input fields readonly, so it cannot be set with default value.
  // This is what the test would look like though if browsers let us automate this test.
  QUnit.test('non-blank file form input field should abort remote request, but submit normally', function(assert) {
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

  QUnit.test('file form input field should not abort remote request if file form input does not have a name attribute', function(assert) {
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

  QUnit.test('blank file input field should abort request entirely if handler bound to "ajax:aborted:file" event that returns false', function(assert) {
    var form = $('form[data-remote]')
          .append($('<input type="file" name="attachment" value="default.png">'))
          .bindNative('ajax:beforeSend', function() {
            ok(false, 'ajax:beforeSend should not run')
          })
          .bind('iframe:loading', function() {
            ok(false, 'form should not get submitted')
          })
          .bindNative('ajax:aborted:file', function(e) {
            e.preventDefault()
          })
          .triggerNative('submit')

    setTimeout(function() {
      form.find('input[type="file"]').val('')
      form.unbind('ajax:beforeSend')
      submit()
    }, 13)
  })
}

QUnit.test('"ajax:beforeSend" can be observed and stopped with event delegation', function(assert) {
  const done = assert.async()

  $(document).delegate('form[data-remote]', 'ajax:beforeSend', function(e) {
    assert.ok(true, 'ajax:beforeSend observed with event delegation')
    e.preventDefault()
  })

  submit(function(form) {
    form.unbind('ajax:send').bindNative('ajax:send', function() {
      assert.ok(false, 'ajax:send should not run')
    })
    form.bindNative('ajax:complete', function() {
      assert.ok(false, 'ajax:complete should not run')
    })
  })

  setTimeout(function() { done() }, 13)
})

QUnit.test('"ajax:beforeSend", "ajax:send", "ajax:success" and "ajax:complete" are triggered', function(assert) {
  const done = assert.async(4)

  submit(function(form) {
    form.bindNative('ajax:beforeSend', function(e, xhr, settings) {
      assert.ok(xhr.setRequestHeader, 'first argument to "ajax:beforeSend" should be an XHR object')
      assert.equal(settings.url, '/echo', 'second argument to "ajax:beforeSend" should be a settings object')
      done()
    })
    form.bindNative('ajax:send', function(e, xhr) {
      assert.ok(xhr.abort, 'first argument to "ajax:send" should be an XHR object')
      done()
    })
    form.bindNative('ajax:success', function(e, data, status, xhr) {
      assert.ok(data.REQUEST_METHOD, 'first argument to ajax:success should be a data object')
      assert.equal(status, 'OK', 'second argument to ajax:success should be a status string')
      assert.ok(xhr.getResponseHeader, 'third argument to "ajax:success" should be an XHR object')
      done()
    })
    form.bindNative('ajax:complete', function(e, xhr, status) {
      assert.ok(xhr.getResponseHeader, 'first argument to "ajax:complete" should be an XHR object')
      assert.equal(status, 'OK', 'second argument to ajax:complete should be a status string')
      done()
    })
  })
})

QUnit.test('"ajax:beforeSend", "ajax:send", "ajax:error" and "ajax:complete" are triggered on error', function(assert) {
  const done = assert.async(4)

  submit(function(form) {
    form.attr('action', '/error')
    form.bindNative('ajax:beforeSend', function(arg) {
      assert.ok(true, 'ajax:beforeSend')
      done()
    })
    form.bindNative('ajax:send', function(arg) {
      assert.ok(true, 'ajax:send')
      done()
    })
    form.bindNative('ajax:error', function(e, response, status, xhr) {
      assert.equal(response, '', 'first argument to ajax:error should be an HTTP status response')
      assert.equal(status, 'Forbidden', 'second argument to ajax:error should be a status string')
      assert.ok(xhr.getResponseHeader, 'third argument to "ajax:error" should be an XHR object')
      // Opera returns "0" for HTTP code
      assert.equal(xhr.status, window.opera ? 0 : 403, 'status code should be 403')
      done()
    })
    form.bindNative('ajax:complete', function(e, xhr, status) {
      assert.ok(xhr.getResponseHeader, 'first argument to "ajax:complete" should be an XHR object')
      assert.equal(status, 'Forbidden', 'second argument to ajax:complete should be a status string')
      done()
    })
  })
})

QUnit.test('binding to ajax callbacks via .delegate() triggers handlers properly', function(assert) {
  const done = assert.async(4)

  $(document)
    .delegate('form[data-remote]', 'ajax:beforeSend', function() {
      assert.ok(true, 'ajax:beforeSend handler is triggered')
      done()
    })
    .delegate('form[data-remote]', 'ajax:send', function() {
      assert.ok(true, 'ajax:send handler is triggered')
      done()
    })
    .delegate('form[data-remote]', 'ajax:success', function() {
      assert.ok(true, 'ajax:success handler is triggered')
      done()
    })
    .delegate('form[data-remote]', 'ajax:complete', function() {
      assert.ok(true, 'ajax:complete handler is triggered')
      done()
    })
  $('form[data-remote]').triggerNative('submit')
})
