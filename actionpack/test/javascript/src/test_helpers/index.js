// Stub navigator.credentials for WebAuthn tests.
// Returns predictable credential objects so we can assert on form field values.

const encoder = new TextEncoder()
const originalCredentials = navigator.credentials

export function stubCredentialsCreate(response = {}) {
  const fake = {
    create: async () => ({
      id: "credential-id",
      rawId: encoder.encode("credential-id").buffer,
      type: "public-key",
      response: {
        clientDataJSON: encoder.encode(JSON.stringify({
          challenge: "test-challenge",
          origin: "https://example.com",
          type: "webauthn.create"
        })).buffer,
        attestationObject: new Uint8Array([1, 2, 3]).buffer,
        getTransports: () => response.transports || ["internal", "hybrid"]
      }
    }),
    get: originalCredentials?.get?.bind(originalCredentials)
  }

  Object.defineProperty(navigator, "credentials", { value: fake, writable: true, configurable: true })
  return () => Object.defineProperty(navigator, "credentials", { value: originalCredentials, writable: true, configurable: true })
}

export function stubCredentialsGet(response = {}) {
  const fake = {
    create: originalCredentials?.create?.bind(originalCredentials),
    get: async () => ({
      id: response.id || "credential-id",
      rawId: encoder.encode("credential-id").buffer,
      type: "public-key",
      response: {
        clientDataJSON: encoder.encode(JSON.stringify({
          challenge: "test-challenge",
          origin: "https://example.com",
          type: "webauthn.get"
        })).buffer,
        authenticatorData: new Uint8Array([4, 5, 6]).buffer,
        signature: new Uint8Array([7, 8, 9]).buffer
      }
    })
  }

  Object.defineProperty(navigator, "credentials", { value: fake, writable: true, configurable: true })
  return () => Object.defineProperty(navigator, "credentials", { value: originalCredentials, writable: true, configurable: true })
}

export function stubFetch(responseBody = { challenge: "fresh-challenge" }, status = 200) {
  const original = window.fetch
  window.fetch = async () => ({
    ok: status >= 200 && status < 300,
    status,
    json: async () => responseBody
  })
  return () => { window.fetch = original }
}

export function createMetaTag(name, content) {
  const meta = document.createElement("meta")
  meta.setAttribute("name", name)
  meta.setAttribute("content", content)
  document.head.appendChild(meta)
  return () => document.head.removeChild(meta)
}

export function createComponent(tagName, attributes = {}, innerHTML = "") {
  const el = document.createElement(tagName)
  for (const [key, value] of Object.entries(attributes)) {
    el.setAttribute(key, value)
  }
  el.innerHTML = innerHTML
  document.body.appendChild(el)
  return el
}

export function removeComponent(el) {
  if (el.parentNode) el.parentNode.removeChild(el)
}

export function registrationFormHTML(action = "/passkeys") {
  return `
    <form method="post" action="${action}">
      <input type="hidden" name="authenticity_token" value="test-token">
      <input type="hidden" name="passkey[client_data_json]" data-passkey-field="client_data_json">
      <input type="hidden" name="passkey[attestation_object]" data-passkey-field="attestation_object">
      <input type="hidden" name="passkey[transports][]" data-passkey-field="transports">
      <button type="button" data-passkey="register">Register</button>
    </form>
    <div hidden data-passkey-error="error">Error</div>
    <div hidden data-passkey-error="cancelled">Cancelled</div>
    <div hidden data-passkey-error="duplicate">Duplicate</div>
  `
}

export function signInFormHTML(action = "/session/passkey") {
  return `
    <form method="post" action="${action}">
      <input type="hidden" name="authenticity_token" value="test-token">
      <input type="hidden" name="passkey[id]" data-passkey-field="id">
      <input type="hidden" name="passkey[client_data_json]" data-passkey-field="client_data_json">
      <input type="hidden" name="passkey[authenticator_data]" data-passkey-field="authenticator_data">
      <input type="hidden" name="passkey[signature]" data-passkey-field="signature">
      <button type="button" data-passkey="sign_in">Sign in</button>
    </form>
    <div hidden data-passkey-error="error">Error</div>
    <div hidden data-passkey-error="cancelled">Cancelled</div>
  `
}
