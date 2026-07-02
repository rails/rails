// Web components for the ActionPack::Passkey Ruby helpers.
//
// <rails-passkey-registration-button> — wraps a registration ceremony form
// <rails-passkey-sign-in-button>  — wraps an authentication ceremony form
//
// The Ruby form helpers render the component markup including the inner form,
// hidden fields, button, and error messages. The components handle the WebAuthn
// ceremony lifecycle (challenge refresh, credential creation/authentication,
// form submission) and error state toggling.
//
// Custom events (all bubble):
//   passkey:start   — ceremony begun
//   passkey:success — credential obtained, form about to submit
//   passkey:error   — ceremony failed; detail: { error, type }
//
// Attributes (rendered by the Ruby form helpers):
//   options       — JSON WebAuthn options (creation or request, on both)
//   challenge-url — endpoint to refresh the challenge nonce (on both)
//   mediation     — WebAuthn mediation hint, e.g. "conditional" (on rails-passkey-sign-in-button)

import { register, authenticate } from "./webauthn"

// Base class for passkey web components. Manages the shared ceremony lifecycle:
// challenge refresh, button state, error display, and event dispatch.
// Subclasses implement `perform()` to run the specific WebAuthn ceremony
// and `fillForm()` to populate hidden fields before submission.
class PasskeyButton extends HTMLElement {
  connectedCallback() {
    this._performBound = () => this._performCeremony()
    this.button.addEventListener("click", this._performBound)
  }

  disconnectedCallback() {
    this.abortConditionalMediation?.()
    this.button.removeEventListener("click", this._performBound)
    this.button.disabled = false
    hideErrors(this)
  }

  get button() {
    return this.querySelector("[data-passkey]")
  }

  get form() {
    return this.querySelector("form")
  }

  get options() {
    return JSON.parse(this.getAttribute("options"))
  }

  get challengeUrl() {
    return this.getAttribute("challenge-url")
  }

  async _performCeremony() {
    await this.abortConditionalMediation?.()
    this.button.disabled = true
    hideErrors(this)
    this.button.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

    try {
      const options = this.options

      if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser")
      if (!options) throw new Error("Missing passkey options")

      await refreshChallenge(options, this.challengeUrl, this.purpose)
      const passkey = await this.perform(options)

      this.button.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      this.fillForm(passkey)
      this.form.submit()
    } catch (error) {
      this.button.disabled = false
      handleError(this, error)
    }
  }
}

class PasskeyRegistrationButton extends PasskeyButton {
  get purpose() { return "registration" }

  async perform(options) {
    return await register(options)
  }

  fillForm(passkey) {
    fillRegistrationForm(this.form, passkey)
  }
}

class PasskeySignInButton extends PasskeyButton {
  get purpose() { return "authentication" }

  connectedCallback() {
    super.connectedCallback()
    this._conditionalMediationController = null
    this._conditionalMediationPromise = null
    if (this.mediation === "conditional") this._attemptConditionalMediation()
  }

  get mediation() {
    return this.getAttribute("mediation")
  }

  async perform(options, { signal, mediation } = {}) {
    return await authenticate(options, { signal, mediation })
  }

  fillForm(passkey) {
    fillSignInForm(this.form, passkey)
  }

  async abortConditionalMediation() {
    if (this._conditionalMediationController) {
      this._conditionalMediationController.abort()
      await this._conditionalMediationPromise
    }
  }

  async _attemptConditionalMediation() {
    const available = this.options &&
      passkeysAvailable() &&
      await window.PublicKeyCredential.isConditionalMediationAvailable?.()

    if (available) {
      const options = this.options

      this.form.dispatchEvent(new CustomEvent("passkey:start", { bubbles: true }))

      this._conditionalMediationController = new AbortController()
      this._conditionalMediationPromise = this._runConditionalMediation(options)
    }
  }

  async _runConditionalMediation(options) {
    try {
      await refreshChallenge(options, this.challengeUrl, this.purpose)
      const passkey = await this.perform(options, { signal: this._conditionalMediationController.signal, mediation: this.mediation })

      this.form.dispatchEvent(new CustomEvent("passkey:success", { bubbles: true }))
      this.fillForm(passkey)
      this.form.submit()
    } catch (error) {
      if (error.name === "AbortError") return

      const type = errorType(error)
      this.button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, type } }))
    } finally {
      this._conditionalMediationController = null
      this._conditionalMediationPromise = null
    }
  }
}

customElements.define("rails-passkey-registration-button", PasskeyRegistrationButton)
customElements.define("rails-passkey-sign-in-button", PasskeySignInButton)

// -- Shared helpers ----------------------------------------------------------

function handleError(component, error) {
  const type = errorType(error)
  showError(component, type)
  component.button.dispatchEvent(new CustomEvent("passkey:error", { bubbles: true, detail: { error, type } }))
}

function errorType(error) {
  switch (error.name) {
    case "AbortError":
    case "NotAllowedError": return "cancelled"
    case "InvalidStateError": return "duplicate"
    default: return "error"
  }
}

function showError(component, type) {
  const el = component.querySelector(`[data-passkey-error="${type}"]`)
  if (el) el.hidden = false
}

function hideErrors(component) {
  for (const el of component.querySelectorAll("[data-passkey-error]")) el.hidden = true
}

function passkeysAvailable() {
  return !!window.PublicKeyCredential
}

async function refreshChallenge(options, challengeUrl, purpose) {
  if (!challengeUrl) throw new Error("Missing passkey challenge URL")

  const body = new URLSearchParams()
  if (purpose) body.append("purpose", purpose)

  const response = await fetch(challengeUrl, {
    method: "POST",
    headers: { "Accept": "application/json" },
    body
  })

  if (!response.ok) throw new Error("Failed to refresh challenge")

  const { challenge } = await response.json()
  options.challenge = challenge
}

function fillRegistrationForm(form, passkey) {
  form.querySelector("[data-passkey-field=\"client_data_json\"]").value = passkey.client_data_json
  form.querySelector("[data-passkey-field=\"attestation_object\"]").value = passkey.attestation_object

  const template = form.querySelector("[data-passkey-field=\"transports\"]")
  for (const transport of passkey.transports) {
    const input = template.cloneNode()
    input.value = transport
    template.before(input)
  }
  template.remove()
}

function fillSignInForm(form, passkey) {
  form.querySelector("[data-passkey-field=\"id\"]").value = passkey.id
  form.querySelector("[data-passkey-field=\"client_data_json\"]").value = passkey.client_data_json
  form.querySelector("[data-passkey-field=\"authenticator_data\"]").value = passkey.authenticator_data
  form.querySelector("[data-passkey-field=\"signature\"]").value = passkey.signature
}
