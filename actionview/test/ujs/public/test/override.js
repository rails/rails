(function() {

var realHref

QUnit.module('override', {
  beforeEach: function() {
    realHref = $.rails.href
    $('#qunit-fixture')
      .append($('<a />', {
        href: '/real/href', 'data-remote': 'true', 'data-method': 'delete', 'data-href': '/data/href'
      }))
  },
  afterEach: function() {
    $.rails.href = realHref
  }
})

QUnit.test('the getter for an element\'s href is publicly accessible', function(assert) {
  assert.expect(1)
  var done = assert.async()

  assert.ok($.rails.href)
  done()
})

QUnit.test('the getter for an element\'s href is overridable', function(assert) {
  assert.expect(1)
  var done = assert.async()

  $.rails.href = function(element) { return $(element).data('href') }
  $('#qunit-fixture a')
    .bindNative('ajax:beforeSend', function(e, xhr, options) {
      assert.equal('/data/href', options.url)
      e.preventDefault()
    })
    .triggerNative('click')
  done()
})

QUnit.test('the getter for an element\'s href works normally if not overridden', function(assert) {
  assert.expect(1)
  var done = assert.async()

  $('#qunit-fixture a')
    .bindNative('ajax:beforeSend', function(e, xhr, options) {
      assert.equal(location.protocol + '//' + location.host + '/real/href', options.url)
      e.preventDefault()
    })
    .triggerNative('click')
  done()
})

QUnit.test('the event selector strings are overridable', function(assert) {
  assert.expect(1)
  var done = assert.async()

  assert.ok($.rails.linkClickSelector.indexOf(', a[data-custom-remote-link]') != -1, 'linkClickSelector contains custom selector')
  done()
})

QUnit.test('including rails-ujs multiple times throws error', function(assert) {
  assert.expect(1)
  var done = assert.async()

  assert.throws(function() {
    Rails.start()
  }, 'appending rails.js again throws error')
  setTimeout(function() { done() }, 50)
})

})()
