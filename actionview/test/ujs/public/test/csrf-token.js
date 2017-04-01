(function() {

QUnit.module('csrf-token', {})

QUnit.test('find csrf token', function(assert) {
  var done = assert.async();

  var correctToken = 'cf50faa3fe97702ca1ae'

  $('#qunit-fixture').append('<meta name="csrf-token" content="' + correctToken + '"/>')

  currentToken = $.rails.csrfToken()

  setTimeout(function() {
    assert.equal(currentToken, correctToken)
    done()
  }, 10);
})

QUnit.test('find csrf param', function(assert) {
  var done = assert.async();

  var correctParam = 'authenticity_token'

  $('#qunit-fixture').append('<meta name="csrf-param" content="' + correctParam + '"/>')

  currentParam = $.rails.csrfParam()

  setTimeout(function() {
    assert.equal(currentParam, correctParam)
    done()
  }, 10);
})

})()
