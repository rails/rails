(function() {

function buildForm(attrs) {
  attrs = $.extend({ action: '/echo', 'data-remote': 'true' }, attrs)

  $('#qunit-fixture').append($('<form />', attrs))
    .find('form').append($('<input type="text" name="user_name" value="john">'))
}

module('call-remote')

function submit(fn) {
  $('form')
    .bindNative('ajax:success', fn)
    .bindNative('ajax:complete', function() { start() })
    .triggerNative('submit')
}

asyncTest('form method is read from "method" and not from "data-method"', 1, function() {
  buildForm({ method: 'post', 'data-method': 'get' })

  submit(function(e, data, status, xhr) {
    App.assertPostRequest(data)
  })
})

asyncTest('form method is not read from "data-method" attribute in case of missing "method"', 1, function() {
  buildForm({ 'data-method': 'put' })

  submit(function(e, data, status, xhr) {
    App.assertGetRequest(data)
  })
})

asyncTest('form method is read from submit button "formmethod" if submit is triggered by that button', 1, function() {
  var submitButton = $('<input type="submit" formmethod="get">')
  buildForm({ method: 'post' })

  $('#qunit-fixture').find('form').append(submitButton)
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertGetRequest(data)
    })
    .bindNative('ajax:complete', function() { start() })

  submitButton.triggerNative('click')
})

asyncTest('form default method is GET', 1, function() {
  buildForm()

  submit(function(e, data, status, xhr) {
    App.assertGetRequest(data)
  })
})

asyncTest('form url is picked up from "action"', 1, function() {
  buildForm({ method: 'post' })

  submit(function(e, data, status, xhr) {
    App.assertRequestPath(data, '/echo')
  })
})

asyncTest('form url is read from "action" not "href"', 1, function() {
  buildForm({ method: 'post', href: '/echo2' })

  submit(function(e, data, status, xhr) {
    App.assertRequestPath(data, '/echo')
  })
})

asyncTest('form url is read from submit button "formaction" if submit is triggered by that button', 1, function() {
  var submitButton = $('<input type="submit" formaction="/echo">')
  buildForm({ method: 'post', href: '/echo2' })

  $('#qunit-fixture').find('form').append(submitButton)
    .bindNative('ajax:success', function(e, data, status, xhr) {
      App.assertRequestPath(data, '/echo')
    })
    .bindNative('ajax:complete', function() { start() })

  submitButton.triggerNative('click')
})

asyncTest('prefer JS, but accept any format', 1, function() {
  buildForm({ method: 'post' })

  submit(function(e, data, status, xhr) {
    var accept = data.HTTP_ACCEPT
    ok(accept.match(/text\/javascript.+\*\/\*/), 'Accept: ' + accept)
  })
})

asyncTest('JS code should be executed', 1, function() {
  buildForm({ method: 'post', 'data-type': 'script' })

  $('form').append('<input type="text" name="content_type" value="text/javascript">')
  $('form').append('<input type="text" name="content" value="ok(true, \'remote code should be run\')">')

  submit()
})

asyncTest('ecmascript code should be executed', 1, function() {
  buildForm({ method: 'post', 'data-type': 'script' })

  $('form').append('<input type="text" name="content_type" value="application/ecmascript">')
  $('form').append('<input type="text" name="content" value="ok(true, \'remote code should be run\')">')

  submit()
})

asyncTest('execution of JS code does not modify current DOM', 1, function() {
  var docLength, newDocLength
  function getDocLength() {
    return document.documentElement.outerHTML.length
  }

  buildForm({ method: 'post', 'data-type': 'script' })

  $('form').append('<input type="text" name="content_type" value="text/javascript">')
  $('form').append('<input type="text" name="content" value="\'remote code should be run\'">')

  docLength = getDocLength()

  submit(function() {
    newDocLength = getDocLength()
    ok(docLength === newDocLength, 'executed JS should not present in the document')
  })
})

asyncTest('XML document should be parsed', 1, function() {
  buildForm({ method: 'post', 'data-type': 'html' })

  $('form').append('<input type="text" name="content_type" value="application/xml">')
  $('form').append('<input type="text" name="content" value="<p>hello</p>">')

  submit(function(e, data, status, xhr) {
    ok(data instanceof Document, 'returned data should be an XML document')
  })
})

asyncTest('accept application/json if "data-type" is json', 1, function() {
  buildForm({ method: 'post', 'data-type': 'json' })

  submit(function(e, data, status, xhr) {
    equal(data.HTTP_ACCEPT, 'application/json, text/javascript, */*; q=0.01')
  })
})

asyncTest('allow empty "data-remote" attribute', 1, function() {
  var form = $('#qunit-fixture').append($('<form action="/echo" data-remote />')).find('form')

  submit(function() {
    ok(true, 'form with empty "data-remote" attribute is also allowed')
  })
})

asyncTest('query string in form action should be stripped in a GET request in normal submit', 1, function() {
  buildForm({ action: '/echo?param1=abc', 'data-remote': 'false' })

  $(document).one('iframe:loaded', function(e, data) {
    equal(data.params.param1, undefined, '"param1" should not be passed to server')
    start()
  })

  $('#qunit-fixture form').triggerNative('submit')
})

asyncTest('query string in form action should be stripped in a GET request in ajax submit', 1, function() {
  buildForm({ action: '/echo?param1=abc' })

  submit(function(e, data, status, xhr) {
    equal(data.params.param1, undefined, '"param1" should not be passed to server')
  })
})

asyncTest('query string in form action should not be stripped in a POST request in normal submit', 1, function() {
  buildForm({ action: '/echo?param1=abc', method: 'post', 'data-remote': 'false' })

  $(document).one('iframe:loaded', function(e, data) {
    equal(data.params.param1, 'abc', '"param1" should be passed to server')
    start()
  })

  $('#qunit-fixture form').triggerNative('submit')
})

asyncTest('query string in form action should not be stripped in a POST request in ajax submit', 1, function() {
  buildForm({ action: '/echo?param1=abc', method: 'post' })

  submit(function(e, data, status, xhr) {
    equal(data.params.param1, 'abc', '"param1" should be passed to server')
  })
})

asyncTest('allow empty form "action"', 1, function() {
  var currentLocation, ajaxLocation

  buildForm({ action: '' })

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(e, xhr, settings) {
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
      equal(ajaxLocation.match(/^(.*)/)[1], currentLocation, 'URL should be current page by default')

      // Prevent the request from actually getting sent to the current page and
      // causing an error.
      return false
    })
    .triggerNative('submit')

  setTimeout(function() { start() }, 13)
})

asyncTest('sends CSRF token in custom header', 1, function() {
  buildForm({ method: 'post' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  submit(function(e, data, status, xhr) {
    equal(data.HTTP_X_CSRF_TOKEN, 'cf50faa3fe97702ca1ae', 'X-CSRF-Token header should be sent')
  })
})

asyncTest('intelligently guesses crossDomain behavior when target URL has a different protocol and/or hostname', 1, function() {

  // Don't set data-cross-domain here, just set action to be a different domain than localhost
  buildForm({ action: 'http://www.alfajango.com' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(evt, req, settings) {

      equal(settings.crossDomain, true, 'crossDomain should be set to true')

      // prevent request from actually getting sent off-domain
      return false
    })
    .triggerNative('submit')

  setTimeout(function() { start() }, 13)
})

asyncTest('intelligently guesses crossDomain behavior when target URL consists of only a path', 1, function() {

  // Don't set data-cross-domain here, just set action to be a different domain than localhost
  buildForm({ action: '/just/a/path' })
  $('#qunit-fixture').append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae" />')

  $('#qunit-fixture').find('form')
    .bindNative('ajax:beforeSend', function(evt, req, settings) {

      equal(settings.crossDomain, false, 'crossDomain should be set to false')

      // prevent request from actually getting sent off-domain
      return false
    })
    .triggerNative('submit')

  setTimeout(function() { start() }, 13)
})

})()
