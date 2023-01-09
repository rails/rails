import $ from 'jquery'
import Rails from "../../../../app/javascript/rails-ujs/index"

QUnit.module('call-ajax', {
  beforeEach: function() {
    $('#qunit-fixture')
      .append($('<a />', { href: '#' }))
  }
})

QUnit.test('call ajax without "ajax:beforeSend"', function(assert) {
  const done = assert.async()

  var link = $('#qunit-fixture a')
  link.bindNative('click', function() {
    Rails.ajax({
      type: 'get',
      url: '/',
      success: function() {
        assert.ok(true, 'calling request in ajax:success')
        done()
      }
    })
  })

  link.triggerNative('click')
})
