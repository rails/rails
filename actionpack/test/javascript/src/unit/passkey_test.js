import "../../../../lib/passkeys/app/javascript/action_pack/passkey"
import {
  stubCredentialsCreate,
  stubCredentialsGet,
  stubFetch,
  createComponent,
  removeComponent,
  registrationFormHTML,
  signInFormHTML
} from "../test_helpers/index"

const { module, test } = QUnit

function waitForEvent(target, eventName) {
  return new Promise(resolve => {
    target.addEventListener(eventName, resolve, { once: true })
  })
}

module("PasskeyRegistrationButton", hooks => {
  let element, restoreFetch, restoreCredentials

  hooks.beforeEach(() => {
    restoreFetch = stubFetch()
    restoreCredentials = stubCredentialsCreate()
  })

  hooks.afterEach(() => {
    if (element) removeComponent(element)
    restoreFetch()
    restoreCredentials()
  })

  test("renders as a custom element", assert => {
    element = createComponent("rails-passkey-registration-button", {
      options: JSON.stringify({ rp: { id: "example.com" } }),
      "challenge-url": "/challenge"
    }, registrationFormHTML())

    assert.ok(element instanceof HTMLElement)
    assert.ok(element.querySelector("[data-passkey]"), "has a passkey button")
    assert.ok(element.querySelector("form"), "has a form")
  })

  test("dispatches passkey:start on click", async assert => {
    element = createComponent("rails-passkey-registration-button", {
      options: JSON.stringify({
        challenge: btoa("test"),
        rp: { id: "example.com", name: "Example App" },
        user: { id: btoa("user-1"), name: "jane@example.com", displayName: "Jane Doe" },
        pubKeyCredParams: [{ type: "public-key", alg: -7 }]
      }),
      "challenge-url": "/challenge"
    }, registrationFormHTML())

    element.querySelector("form").submit = () => {}

    const eventPromise = waitForEvent(element, "passkey:start")
    element.querySelector("[data-passkey]").click()
    await eventPromise

    assert.ok(true, "passkey:start was dispatched")
  })

  test("fills form fields after ceremony", async assert => {
    element = createComponent("rails-passkey-registration-button", {
      options: JSON.stringify({
        challenge: btoa("test"),
        rp: { id: "example.com", name: "Example App" },
        user: { id: btoa("user-1"), name: "jane@example.com", displayName: "Jane Doe" },
        pubKeyCredParams: [{ type: "public-key", alg: -7 }]
      }),
      "challenge-url": "/challenge"
    }, registrationFormHTML())

    const form = element.querySelector("form")
    const submitted = new Promise(resolve => { form.submit = resolve })

    element.querySelector("[data-passkey]").click()
    await submitted

    const clientDataJson = form.querySelector("[data-passkey-field=\"client_data_json\"]").value
    const attestationObject = form.querySelector("[data-passkey-field=\"attestation_object\"]").value

    assert.ok(clientDataJson, "client_data_json is filled")
    assert.ok(attestationObject, "attestation_object is filled")
  })

  test("shows error message on failure", async assert => {
    restoreFetch()
    restoreFetch = stubFetch({}, 500)

    element = createComponent("rails-passkey-registration-button", {
      options: JSON.stringify({ rp: { id: "example.com" } }),
      "challenge-url": "/challenge"
    }, registrationFormHTML())

    const eventPromise = waitForEvent(element, "passkey:error")
    element.querySelector("[data-passkey]").click()
    const { detail } = await eventPromise

    assert.equal(detail.type, "error", "error type is 'error'")

    const errorDiv = element.querySelector("[data-passkey-error=\"error\"]")
    assert.false(errorDiv.hidden, "error message is visible")
  })

  test("disables button during ceremony", async assert => {
    element = createComponent("rails-passkey-registration-button", {
      options: JSON.stringify({
        challenge: btoa("test"),
        rp: { id: "example.com", name: "Example App" },
        user: { id: btoa("user-1"), name: "jane@example.com", displayName: "Jane Doe" },
        pubKeyCredParams: [{ type: "public-key", alg: -7 }]
      }),
      "challenge-url": "/challenge"
    }, registrationFormHTML())

    const button = element.querySelector("[data-passkey]")
    const form = element.querySelector("form")

    const startPromise = waitForEvent(element, "passkey:start")
    const submitted = new Promise(resolve => { form.submit = resolve })

    button.click()
    await startPromise

    assert.true(button.disabled, "button is disabled during ceremony")
    await submitted
  })
})

module("PasskeySignInButton", hooks => {
  let element, restoreFetch, restoreCredentials

  hooks.beforeEach(() => {
    restoreFetch = stubFetch()
    restoreCredentials = stubCredentialsGet({ id: "cred-42" })
  })

  hooks.afterEach(() => {
    if (element) removeComponent(element)
    restoreFetch()
    restoreCredentials()
  })

  test("renders as a custom element", assert => {
    element = createComponent("rails-passkey-sign-in-button", {
      options: JSON.stringify({ rpId: "example.com" }),
      "challenge-url": "/challenge"
    }, signInFormHTML())

    assert.ok(element instanceof HTMLElement)
    assert.ok(element.querySelector("[data-passkey]"), "has a passkey button")
  })

  test("fills sign-in form fields", async assert => {
    element = createComponent("rails-passkey-sign-in-button", {
      options: JSON.stringify({
        challenge: btoa("test"),
        rpId: "example.com",
        allowCredentials: []
      }),
      "challenge-url": "/challenge"
    }, signInFormHTML())

    const form = element.querySelector("form")
    const submitted = new Promise(resolve => { form.submit = resolve })

    element.querySelector("[data-passkey]").click()
    await submitted

    assert.equal(form.querySelector("[data-passkey-field=\"id\"]").value, "cred-42", "credential id is filled")
    assert.ok(form.querySelector("[data-passkey-field=\"client_data_json\"]").value, "client_data_json is filled")
    assert.ok(form.querySelector("[data-passkey-field=\"authenticator_data\"]").value, "authenticator_data is filled")
    assert.ok(form.querySelector("[data-passkey-field=\"signature\"]").value, "signature is filled")
  })

  test("refreshes challenge before ceremony", async assert => {
    let fetchedURL, fetchedMethod

    restoreFetch()
    const originalFetch = window.fetch
    window.fetch = async (url, opts) => {
      fetchedURL = url
      fetchedMethod = opts.method
      return { ok: true, json: async () => ({ challenge: "new-challenge" }) }
    }
    restoreFetch = () => { window.fetch = originalFetch }

    element = createComponent("rails-passkey-sign-in-button", {
      options: JSON.stringify({
        challenge: btoa("old"),
        rpId: "example.com",
        allowCredentials: []
      }),
      "challenge-url": "/challenge"
    }, signInFormHTML())

    const form = element.querySelector("form")
    const submitted = new Promise(resolve => { form.submit = resolve })
    const errorEvent = waitForEvent(element, "passkey:error")

    element.querySelector("[data-passkey]").click()

    await Promise.race([submitted, errorEvent])

    assert.equal(fetchedURL, "/challenge", "fetches challenge URL")
    assert.equal(fetchedMethod, "POST", "uses POST")
  })

  test("shows cancelled message on NotAllowedError", async assert => {
    restoreCredentials()
    const orig = navigator.credentials
    Object.defineProperty(navigator, "credentials", {
      value: {
        get: async () => { throw new DOMException("User cancelled", "NotAllowedError") }
      },
      writable: true,
      configurable: true
    })
    restoreCredentials = () => Object.defineProperty(navigator, "credentials", { value: orig, writable: true, configurable: true })

    element = createComponent("rails-passkey-sign-in-button", {
      options: JSON.stringify({
        challenge: btoa("test"),
        rpId: "example.com",
        allowCredentials: []
      }),
      "challenge-url": "/challenge"
    }, signInFormHTML())

    const eventPromise = waitForEvent(element, "passkey:error")
    element.querySelector("[data-passkey]").click()
    const { detail } = await eventPromise

    assert.equal(detail.type, "cancelled", "error type is cancelled")

    const cancelledDiv = element.querySelector("[data-passkey-error=\"cancelled\"]")
    assert.false(cancelledDiv.hidden, "cancelled message is visible")

    const errorDiv = element.querySelector("[data-passkey-error=\"error\"]")
    assert.true(errorDiv.hidden, "error message stays hidden")
  })

  test("re-enables button after error", async assert => {
    restoreFetch()
    restoreFetch = stubFetch({}, 500)

    element = createComponent("rails-passkey-sign-in-button", {
      options: JSON.stringify({ rpId: "example.com" }),
      "challenge-url": "/challenge"
    }, signInFormHTML())

    const button = element.querySelector("[data-passkey]")
    const eventPromise = waitForEvent(element, "passkey:error")

    button.click()
    await eventPromise

    assert.false(button.disabled, "button is re-enabled after error")
  })
})
