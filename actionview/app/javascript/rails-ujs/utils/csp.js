let nonce = null

Rails.loadCSPNonce = () => {
  const metaTag = document.querySelector("meta[name=csp-nonce]")
  return nonce = metaTag && metaTag.content
}

// Returns the Content-Security-Policy nonce for inline scripts.
Rails.cspNonce = () => nonce || Rails.loadCSPNonce()
