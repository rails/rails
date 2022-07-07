import { $ } from "./dom"

// Up-to-date Cross-Site Request Forgery token
const csrfToken = () => {
  const meta = document.querySelector("meta[name=csrf-token]")
  return meta && meta.content
}

// URL param that must contain the CSRF token
const csrfParam = () => {
  const meta = document.querySelector("meta[name=csrf-param]")
  return meta && meta.content
}

// Make sure that every Ajax request sends the CSRF token
const CSRFProtection = (xhr) => {
  const token = csrfToken()
  if (token) { return xhr.setRequestHeader("X-CSRF-Token", token) }
}

// Make sure that all forms have actual up-to-date tokens (cached forms contain old ones)
const refreshCSRFTokens = () => {
  const token = csrfToken()
  const param = csrfParam()
  if (token && param) {
    return $("form input[name=\"" + param + "\"]").forEach(input => input.value = token)
  }
}

export { csrfToken, csrfParam, CSRFProtection, refreshCSRFTokens }
