(function() {

module('data-method', {
  setup: function() {
    $('#qunit-fixture').append($('<a />', {
      href: '/echo', 'data-method': 'delete', text: 'destroy!'
    }))
  },
  teardown: function() {
    $(document).unbind('iframe:loaded')
  }
})

function submit(fn, options) {
  $(document).bind('iframe:loaded', function(e, data) {
    fn(data)
    start()
  })

  $('#qunit-fixture').find('a')
    .triggerNative('click')
}

asyncTest('link with "data-method" set to "delete"', 3, function() {
  submit(function(data) {
    equal(data.REQUEST_METHOD, 'DELETE')
    strictEqual(data.params.authenticity_token, undefined)
    strictEqual(data.HTTP_X_CSRF_TOKEN, undefined)
  })
})

asyncTest('click on the child of link with "data-method"', 3, function() {
  $(document).bind('iframe:loaded', function(e, data) {
    equal(data.REQUEST_METHOD, 'DELETE')
    strictEqual(data.params.authenticity_token, undefined)
    strictEqual(data.HTTP_X_CSRF_TOKEN, undefined)
    start()
  })
  $('#qunit-fixture a').html('<strong>destroy!</strong>').find('strong').triggerNative('click')
})

asyncTest('link with "data-method" and CSRF', 1, function() {
  $('#qunit-fixture')
    .append('<meta name="csrf-param" content="authenticity_token"/>')
    .append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae"/>')

  submit(function(data) {
    equal(data.params.authenticity_token, 'cf50faa3fe97702ca1ae')
  })
})

asyncTest('link "target" should be carried over to generated form', 1, function() {
  $('a[data-method]').attr('target', 'super-special-frame')
  submit(function(data) {
    equal(data.params._target, 'super-special-frame')
  })
})

asyncTest('link with "data-method" and cross origin', 1, function() {
  var data = {}

  $('#qunit-fixture')
    .append('<meta name="csrf-param" content="authenticity_token"/>')
    .append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae"/>')

  $(document).on('submit', 'form', function(e) {
    $(e.currentTarget).serializeArray().map(function(item) {
      data[item.name] = item.value
    })

    return false
  })

  var link = $('#qunit-fixture').find('a')

  link.attr('href', 'http://www.alfajango.com')

  link.triggerNative('click')

  start()

  notEqual(data.authenticity_token, 'cf50faa3fe97702ca1ae')
})

})()
