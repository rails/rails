(function() {

module('call-ajax', {
  setup: function() {
    $('#qunit-fixture')
      .append($('<a />', { href: '#' }))
  }
})

asyncTest('call ajax without "ajax:beforeSend"', 1, function() {

  var link = $('#qunit-fixture a')
  link.bindNative('click', function() {
    Rails.ajax({
      type: 'get',
      url: '/',
      success: function() {
        ok(true, 'calling request in ajax:success')
      }
    })
  })

  link.triggerNative('click')
  setTimeout(function() { start() }, 13)
})

})()
