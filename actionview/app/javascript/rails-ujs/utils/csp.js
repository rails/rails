/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__, or convert again using --optional-chaining
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
let nonce = null

Rails.loadCSPNonce = () => nonce = __guard__(document.querySelector("meta[name=csp-nonce]"), x => x.content)

// Returns the Content-Security-Policy nonce for inline scripts.
Rails.cspNonce = () => nonce != null ? nonce : Rails.loadCSPNonce()

function __guard__(value, transform) {
  return (typeof value !== "undefined" && value !== null) ? transform(value) : undefined
}