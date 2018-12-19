(function() {

function buildForm(attrs) {
  attrs = $.extend({ action: '/echo', 'data-remote': 'true', class: 'rails-ujs-target' }, attrs)

  $('#qunit-fixture').append($('<form />', attrs))
    .find('form.rails-ujs-target').append($('<input type="text" name="user_name" value="john">'))
}

QUnit.module('call-remote')

function submit(done, fn) {
  $('form.rails-ujs-target')
    .bindNative('ajax:success', fn)
    .bindNative('ajax:complete', function() { done() })
    .triggerNative('submit')
}

QUnit.test('form method is read from "method" and not from "data-method"', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-method': 'get' })

  submit(done, function(e, data, status, xhr) {
    App.assertPostRequest(assert, data)
  })
})

QUnit.test('form method is not read from "data-method" attribute in case of missing "method"', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ 'data-method': 'put' })

  submit(done, function(e, data, status, xhr) {
    App.assertGetRequest(assert, data)
  })
})

QUnit.test('form method is read from submit button "formmethod" if submit is triggered by that button', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var submitButton = $('<input type="submit" formmethod="get">')
  buildForm({ method: 'post' })

  $('#qunit-fixture').find('form').append(submitButton)
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertGetRequest(assert, data)
    })
    .bindNative('ajax:complete', function() { done() })

  submitButton.triggerNative('click')
})

QUnit.test('form default method is GET', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm()

  submit(done, function(e, data, status, xhr) {
    App.assertGetRequest(assert, data)
  })
})

QUnit.test('form url is picked up from "action"', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post' })

  submit(done, function(e, data, status, xhr) {
    App.assertRequestPath(assert, data, '/echo')
  })
})

QUnit.test('form url is read from "action" not "href"', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', href: '/echo2' })

  submit(done, function(e, data, status, xhr) {
    App.assertRequestPath(assert, data, '/echo')
  })
})

QUnit.test('form url is read from submit button "formaction" if submit is triggered by that button', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var submitButton = $('<input type="submit" formaction="/echo">')
  buildForm({ method: 'post', href: '/echo2' })

  $('#qunit-fixture').find('form').append(submitButton)
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertRequestPath(assert, data, '/echo')
    })
    .bindNative('ajax:complete', function() { done() })

  submitButton.triggerNative('click')
})

QUnit.test('prefer JS, but accept any format', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post' })

  submit(done, function(e, data, status, xhr) {
    var accept = data.HTTP_ACCEPT
    assert.ok(accept.match(/text\/javascript.+\*\/\*/), 'Accept: ' + accept)
  })
})

QUnit.test('JS code should be executed', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-type': 'script' })

  window._callRemoteCallback = function() {
    assert.ok(true, 'remote code should be run')
  }

  $('form.rails-ujs-target').append('<input type="text" name="content_type" value="text/javascript">')
  $('form.rails-ujs-target').append('<input type="text" name="content" value="window._callRemoteCallback()">')

  submit(done)
})

QUnit.test('ecmascript code should be executed', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-type': 'script' })

  window._callRemoteCallback = function() {
    assert.ok(true, 'remote code should be run')
  }

  $('form.rails-ujs-target').append('<input type="text" name="content_type" value="application/ecmascript">')
  $('form.rails-ujs-target').append('<input type="text" name="content" value="window._callRemoteCallback()">')

  submit(done)
})

QUnit.test('execution of JS code does not modify current DOM', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var docLength, newDocLength
  function getDocLength() {
    return document.documentElement.outerHTML.length
  }

  buildForm({ method: 'post', 'data-type': 'script' })

  $('form.rails-ujs-target').append('<input type="text" name="content_type" value="text/javascript">')
  $('form.rails-ujs-target').append('<input type="text" name="content" value="\'remote code should be run\'">')

  docLength = getDocLength()

  submit(done, function() {
    newDocLength = getDocLength()
    assert.ok(docLength === newDocLength, 'executed JS should not present in the document')
  })
})

QUnit.test('HTML content should be plain-text', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-type': 'html' })

  $('form.rails-ujs-target').append('<input type="text" name="content_type" value="text/html">')
  $('form.rails-ujs-target').append('<input type="text" name="content" value="<p>hello</p>">')

  submit(done, function(e, data, status, xhr) {
    assert.ok(data === '<p>hello</p>', 'returned data should be a plain-text string')
  })
})

QUnit.test('XML document should be parsed', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-type': 'html' })

  $('form.rails-ujs-target').append('<input type="text" name="content_type" value="application/xml">')
  $('form.rails-ujs-target').append('<input type="text" name="content" value="<p>hello</p>">')

  submit(done, function(e, data, status, xhr) {
    assert.ok(data instanceof Document, 'returned data should be an XML document')
  })
})

QUnit.test('accept application/json if "data-type" is json', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post', 'data-type': 'json' })

  submit(done, function(e, data, status, xhr) {
    assert.equal(data.HTTP_ACCEPT, 'application/json, text/javascript, */*; q=0.01')
  })
})

QUnit.test('allow empty "data-remote" attribute', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var form = $('#qunit-fixture').append($('<form class=\'rails-ujs-target\' action="/echo" data-remote />')).find('form.rails-ujs-target')
  window._debug = form

  submit(done, function() {
    assert.ok(true, 'form with empty "data-remote" attribute is also allowed')
  })
})

QUnit.test('query string in form action should be stripped in a GET request in normal submit', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ action: '/echo?param1=abc', 'data-remote': 'false' })

  $(document).one('iframe:loaded', function(e, data) {
    assert.equal(data.params.param1, undefined, '"param1" should not be passed to server')
    done()
  })

  $('#qunit-fixture form').triggerNative('submit')
})

QUnit.test('query string in form action should be stripped in a GET request in ajax submit', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ action: '/echo?param1=abc' })

  submit(done, function(e, data, status, xhr) {
    assert.equal(data.params.param1, undefined, '"param1" should not be passed to server')
  })
})

QUnit.test('query string in form action should not be stripped in a POST request in normal submit', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ action: '/echo?param1=abc', method: 'post', 'data-remote': 'false' })

  $(document).one('iframe:loaded', function(e, data) {
    assert.equal(data.params.param1, 'abc', '"param1" should be passed to server')
    done()
  })

  $('#qunit-fixture form').triggerNative('submit')
})

QUnit.test('query string in form action should not be stripped in a POST request in ajax submit', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ action: '/echo?param1=abc', method: 'post' })

  submit(done, function(e, data, status, xhr) {
    assert.equal(data.params.param1, 'abc', '"param1" should be passed to server')
  })
})

QUnit.test('allow empty form "action"', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var currentLocation, ajaxLocation

  buildForm({ action: '' })

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(evt, xhr, settings) {
      // Get current location (the same way jQuery does)
      try {
        currentLocation = location.href
      } catch(err) {
        currentLocation = document.createElement( 'a' )
        currentLocation.href = ''
        currentLocation = currentLocation.href
      }
      currentLocation = currentLocation.replace(/\?.*$/, '')

      // Actual location (strip out settings.data that jQuery serializes and appends)
      // HACK: can no longer use settings.data below to see what was appended to URL, as of
      // jQuery 1.6.3 (see http://bugs.jquery.com/ticket/10202 and https://github.com/jquery/jquery/pull/544)
      ajaxLocation = settings.url.replace('user_name=john', '').replace(/&$/, '').replace(/\?$/, '')
      assert.equal(ajaxLocation.match(/^(.*)/)[1], currentLocation, 'URL should be current page by default')

      // Prevent the request from actually getting sent to the current page and
      // causing an error.
      evt.preventDefault()
    })
    .triggerNative('submit')

  setTimeout(function() { done() }, 13)
})

QUnit.test('sends CSRF token in custom header', function(assert) {
  assert.expect(1)
  var done = assert.async()

  buildForm({ method: 'post' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  submit(done, function(e, data, status, xhr) {
    assert.equal(data.HTTP_X_CSRF_TOKEN, 'cf50faa3fe97702ca1ae', 'X-CSRF-Token header should be sent')
  })
})

QUnit.test('intelligently guesses crossDomain behavior when target URL has a different protocol and/or hostname', function(assert) {
  assert.expect(1)
  var done = assert.async()


  // Don't set data-cross-domain here, just set action to be a different domain than localhost
  buildForm({ action: 'http://www.alfajango.com' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(evt, req, settings) {

      assert.equal(settings.crossDomain, true, 'crossDomain should be set to true')

      // prevent request from actually getting sent off-domain
      evt.preventDefault()
    })
    .triggerNative('submit')

  setTimeout(function() { done() }, 13)
})

QUnit.test('intelligently guesses crossDomain behavior when target URL consists of only a path', function(assert) {
  assert.expect(1)
  var done = assert.async()


  // Don't set data-cross-domain here, just set action to be a different domain than localhost
  buildForm({ action: '/just/a/path' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(evt, req, settings) {

      assert.equal(settings.crossDomain, false, 'crossDomain should be set to false')

      // prevent request from actually getting sent off-domain
      evt.preventDefault()
    })
    .triggerNative('submit')

  setTimeout(function() { done() }, 13)
})

})()
