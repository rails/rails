import $ from 'jquery'

QUnit.module('csrf-token', {})

QUnit.test('find csrf token', function(assert) {
  var correctToken = 'cf50faa3fe97702ca1ae'

  $('#qunit-fixture').append('<meta name="csrf-token" content="' + correctToken + '"/>')

  var currentToken = $.rails.csrfToken()

  assert.equal(currentToken, correctToken)
})

QUnit.test('find csrf param', function(assert) {
  var correctParam = 'authenticity_token'

  $('#qunit-fixture').append('<meta name="csrf-param" content="' + correctParam + '"/>')

  var currentParam = $.rails.csrfParam()

  assert.equal(currentParam, correctParam)
})
