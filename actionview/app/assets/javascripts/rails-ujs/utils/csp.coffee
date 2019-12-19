nonce = null

Rails.loadCSPNonce = ->
  nonce = document.querySelector("meta[name=csp-nonce]")?.content

# Returns the Content-Security-Policy nonce for inline scripts.
Rails.cspNonce = ->
  nonce ? Rails.loadCSPNonce()
