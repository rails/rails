// Must go before rails-ujs.
document.addEventListener('rails:attachBindings', function() {
  // This is for test in override.js.
  window.Rails.linkClickSelector += ', a[data-custom-remote-link]';

  // Hijacks link click before ujs binds any handlers
  // This is only used for ctrl-clicking test on remote links
  window.Rails.delegate(document, '#qunit-fixture a', 'click', function(e) {
    e.preventDefault();
  });
});
