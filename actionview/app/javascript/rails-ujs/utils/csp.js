let nonce = null

const loadCSPNonce = () => {
  const metaTag = document.querySelector("meta[name=csp-nonce]")
  return nonce = metaTag && metaTag.content
}

// Returns the Content-Security-Policy nonce for inline scripts.
const cspNonce = () => nonce || loadCSPNonce()

export { cspNonce, loadCSPNonce }
