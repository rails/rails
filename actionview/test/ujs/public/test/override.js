(function() {

var realHref

module('override', {
  setup: function() {
    realHref = $.rails.href
    $('#qunit-fixture')
      .append($('<a />', {
        href: '/real/href', 'data-remote': 'true', 'data-method': 'delete', 'data-href': '/data/href'
      }))
  },
  teardown: function() {
    $.rails.href = realHref
  }
})

asyncTest('the getter for an element\'s href is publicly accessible', 1, function() {
  ok($.rails.href)
  start()
})

asyncTest('the getter for an element\'s href is overridable', 1, function() {
  $.rails.href = function(element) { return $(element).data('href') }
  $('#qunit-fixture a')
    .bindNative('ajax:beforeSend', function(e, xhr, options) {
      equal('/data/href', options.url)
      e.preventDefault()
    })
    .triggerNative('click')
  start()
})

asyncTest('the getter for an element\'s href works normally if not overridden', 1, function() {
  $('#qunit-fixture a')
    .bindNative('ajax:beforeSend', function(e, xhr, options) {
      equal(location.protocol + '//' + location.host + '/real/href', options.url)
      e.preventDefault()
    })
    .triggerNative('click')
  start()
})

asyncTest('the event selector strings are overridable', 1, function() {
  ok($.rails.linkClickSelector.indexOf(', a[data-custom-remote-link]') != -1, 'linkClickSelector contains custom selector')
  start()
})

asyncTest('including rails-ujs multiple times throws error', 1, function() {
  throws(function() {
    Rails.start()
  }, 'appending rails.js again throws error')
  setTimeout(function() { start() }, 50)
})

})()
