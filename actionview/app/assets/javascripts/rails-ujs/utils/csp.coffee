# Content-Security-Policy nonce for inline scripts
cspNonce = Rails.cspNonce = ->
  meta = document.querySelector('meta[name=csp-nonce]')
  meta and meta.content
