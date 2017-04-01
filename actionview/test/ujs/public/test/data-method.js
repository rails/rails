(function() {

QUnit.module('data-method', {
  beforeEach: function() {
    $('#qunit-fixture').append($('<a />', {
      href: '/echo', 'data-method': 'delete', text: 'destroy!'
    }))
  },
  afterEach: function() {
    $(document).unbind('iframe:loaded')
  }
})

function submit(assert, fn, options) {
  var done = assert.async();

  $(document).bind('iframe:loaded', function(e, data) {
    fn(data)
    done()
  })

  $('#qunit-fixture').find('a')
    .triggerNative('click')
}

QUnit.test('link with "data-method" set to "delete"', function(assert) {
  submit(assert, function(data) {
    assert.equal(data.REQUEST_METHOD, 'DELETE')
    assert.strictEqual(data.params.authenticity_token, undefined)
    assert.strictEqual(data.HTTP_X_CSRF_TOKEN, undefined)
  })
})

QUnit.test('click on the child of link with "data-method"', function(assert) {
  var done = assert.async();

  $(document).bind('iframe:loaded', function(e, data) {
    assert.equal(data.REQUEST_METHOD, 'DELETE')
    assert.strictEqual(data.params.authenticity_token, undefined)
    assert.strictEqual(data.HTTP_X_CSRF_TOKEN, undefined)
    done()
  })
  $('#qunit-fixture a').html('<strong>destroy!</strong>').find('strong').triggerNative('click')
})

QUnit.test('link with "data-method" and CSRF', function(assert) {
  $('#qunit-fixture')
    .append('<meta name="csrf-param" content="authenticity_token"/>')
    .append('<meta name="csrf-token" content="cf50faa3fe97702ca1ae"/>')

  submit(assert, function(data) {
    assert.equal(data.params.authenticity_token, 'cf50faa3fe97702ca1ae')
  })
})

QUnit.test('link "target" should be carried over to generated form', function(assert) {
  $('a[data-method]').attr('target', 'super-special-frame')
  submit(assert, function(data) {
    assert.equal(data.params._target, 'super-special-frame')
  })
})

QUnit.test('link with "data-method" and cross origin', function(assert) {
  var done = assert.async();

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

  setTimeout(function() {
    assert.notEqual(data.authenticity_token, 'cf50faa3fe97702ca1ae')
    done()
  }, 10);
})

})()
