/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Content-Security-Policy nonce for inline scripts
const cspNonce = (Rails.cspNonce = function() {
  const meta = document.querySelector('meta[name=csp-nonce]');
  return meta && meta.content;
});
