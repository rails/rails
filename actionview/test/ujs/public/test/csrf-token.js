(function() {

QUnit.module('csrf-token', {})

QUnit.test('find csrf token', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var correctToken = 'cf50faa3fe97702ca1ae'

  $('#qunit-fixture').append('<meta name="csrf-token" content="' + correctToken + '"/>')

  currentToken = $.rails.csrfToken()

  assert.equal(currentToken, correctToken)
  done()
})

QUnit.test('find csrf param', function(assert) {
  assert.expect(1)
  var done = assert.async()

  var correctParam = 'authenticity_token'

  $('#qunit-fixture').append('<meta name="csrf-param" content="' + correctParam + '"/>')

  currentParam = $.rails.csrfParam()

  assert.equal(currentParam, correctParam)
  done()
})

})()
