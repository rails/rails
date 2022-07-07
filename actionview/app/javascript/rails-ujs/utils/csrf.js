//= require ./dom

const { $ } = Rails

// Up-to-date Cross-Site Request Forgery token
const csrfToken = (Rails.csrfToken = function() {
  const meta = document.querySelector("meta[name=csrf-token]")
  return meta && meta.content
})

// URL param that must contain the CSRF token
const csrfParam = (Rails.csrfParam = function() {
  const meta = document.querySelector("meta[name=csrf-param]")
  return meta && meta.content
})

// Make sure that every Ajax request sends the CSRF token
Rails.CSRFProtection = function(xhr) {
  const token = csrfToken()
  if (token) { return xhr.setRequestHeader("X-CSRF-Token", token) }
}

// Make sure that all forms have actual up-to-date tokens (cached forms contain old ones)
Rails.refreshCSRFTokens = function() {
  const token = csrfToken()
  const param = csrfParam()
  if (token && param) {
    return $("form input[name=\"" + param + "\"]").forEach(input => input.value = token)
  }
}
