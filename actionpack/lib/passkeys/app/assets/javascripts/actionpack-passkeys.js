(function(global, factory) {
  typeof exports === "object" && typeof module !== "undefined" ? factory(exports) : typeof define === "function" && define.amd ? define([ "exports" ], factory) : (global = typeof globalThis !== "undefined" ? globalThis : global || self, 
  factory(global.ActionPack = {}));
})(this, (function(exports) {
  "use strict";
  async function register(options) {
    const publicKey = prepareCreationOptions(options);
    const credential = await navigator.credentials.create({
      publicKey: publicKey
    });
    return {
      client_data_json: (new TextDecoder).decode(credential.response.clientDataJSON),
      attestation_object: bufferToBase64url(credential.response.attestationObject),
      transports: credential.response.getTransports?.() || []
    };
  }
  async function authenticate(options, {signal: signal, mediation: mediation} = {}) {
    const publicKey = prepareRequestOptions(options);
    const credential = await navigator.credentials.get({
      publicKey: publicKey,
      signal: signal,
      mediation: mediation
    });
    return {
      id: credential.id,
      client_data_json: (new TextDecoder).decode(credential.response.clientDataJSON),
      authenticator_data: bufferToBase64url(credential.response.authenticatorData),
      signature: bufferToBase64url(credential.response.signature)
    };
  }
  function prepareCreationOptions(options) {
    return {
      ...options,
      challenge: base64urlToBuffer(options.challenge),
      user: {
        ...options.user,
        id: base64urlToBuffer(options.user.id)
      },
      excludeCredentials: (options.excludeCredentials || []).map((cred => ({
        ...cred,
        id: base64urlToBuffer(cred.id)
      })))
    };
  }
  function prepareRequestOptions(options) {
    const prepared = {
      ...options,
      challenge: base64urlToBuffer(options.challenge)
    };
    if (options.allowCredentials?.length) {
      prepared.allowCredentials = options.allowCredentials.map((cred => ({
        ...cred,
        id: base64urlToBuffer(cred.id)
      })));
    } else {
      delete prepared.allowCredentials;
    }
    return prepared;
  }
  function base64urlToBuffer(base64url) {
    const base64 = base64url.replace(/-/g, "+").replace(/_/g, "/");
    const padding = "=".repeat((4 - base64.length % 4) % 4);
    const binary = atob(base64 + padding);
    return Uint8Array.from(binary, (c => c.charCodeAt(0))).buffer;
  }
  function bufferToBase64url(buffer) {
    const bytes = new Uint8Array(buffer);
    const binary = String.fromCharCode(...bytes);
    return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  }
  class PasskeyButton extends HTMLElement {
    connectedCallback() {
      this._performBound = () => this._performCeremony();
      this.button.addEventListener("click", this._performBound);
    }
    disconnectedCallback() {
      this.abortConditionalMediation?.();
      this.button.removeEventListener("click", this._performBound);
      this.button.disabled = false;
      hideErrors(this);
    }
    get button() {
      return this.querySelector("[data-passkey]");
    }
    get form() {
      return this.querySelector("form");
    }
    get options() {
      return JSON.parse(this.getAttribute("options"));
    }
    get challengeUrl() {
      return this.getAttribute("challenge-url");
    }
    async _performCeremony() {
      await (this.abortConditionalMediation?.());
      this.button.disabled = true;
      hideErrors(this);
      this.button.dispatchEvent(new CustomEvent("passkey:start", {
        bubbles: true
      }));
      try {
        const options = this.options;
        if (!passkeysAvailable()) throw new Error("Passkeys are not supported by this browser");
        if (!options) throw new Error("Missing passkey options");
        await refreshChallenge(options, this.challengeUrl, this.purpose);
        const passkey = await this.perform(options);
        this.button.dispatchEvent(new CustomEvent("passkey:success", {
          bubbles: true
        }));
        this.fillForm(passkey);
        this.form.submit();
      } catch (error) {
        this.button.disabled = false;
        handleError(this, error);
      }
    }
  }
  class PasskeyRegistrationButton extends PasskeyButton {
    get purpose() {
      return "registration";
    }
    async perform(options) {
      return await register(options);
    }
    fillForm(passkey) {
      fillRegistrationForm(this.form, passkey);
    }
  }
  class PasskeySignInButton extends PasskeyButton {
    get purpose() {
      return "authentication";
    }
    connectedCallback() {
      super.connectedCallback();
      this._conditionalMediationController = null;
      this._conditionalMediationPromise = null;
      if (this.mediation === "conditional") this._attemptConditionalMediation();
    }
    get mediation() {
      return this.getAttribute("mediation");
    }
    async perform(options, {signal: signal, mediation: mediation} = {}) {
      return await authenticate(options, {
        signal: signal,
        mediation: mediation
      });
    }
    fillForm(passkey) {
      fillSignInForm(this.form, passkey);
    }
    async abortConditionalMediation() {
      if (this._conditionalMediationController) {
        this._conditionalMediationController.abort();
        await this._conditionalMediationPromise;
      }
    }
    async _attemptConditionalMediation() {
      const available = this.options && passkeysAvailable() && await (window.PublicKeyCredential.isConditionalMediationAvailable?.());
      if (available) {
        const options = this.options;
        this.form.dispatchEvent(new CustomEvent("passkey:start", {
          bubbles: true
        }));
        this._conditionalMediationController = new AbortController;
        this._conditionalMediationPromise = this._runConditionalMediation(options);
      }
    }
    async _runConditionalMediation(options) {
      try {
        await refreshChallenge(options, this.challengeUrl, this.purpose);
        const passkey = await this.perform(options, {
          signal: this._conditionalMediationController.signal,
          mediation: this.mediation
        });
        this.form.dispatchEvent(new CustomEvent("passkey:success", {
          bubbles: true
        }));
        this.fillForm(passkey);
        this.form.submit();
      } catch (error) {
        if (error.name === "AbortError") return;
        const type = errorType(error);
        this.button.dispatchEvent(new CustomEvent("passkey:error", {
          bubbles: true,
          detail: {
            error: error,
            type: type
          }
        }));
      } finally {
        this._conditionalMediationController = null;
        this._conditionalMediationPromise = null;
      }
    }
  }
  customElements.define("rails-passkey-registration-button", PasskeyRegistrationButton);
  customElements.define("rails-passkey-sign-in-button", PasskeySignInButton);
  function handleError(component, error) {
    const type = errorType(error);
    showError(component, type);
    component.button.dispatchEvent(new CustomEvent("passkey:error", {
      bubbles: true,
      detail: {
        error: error,
        type: type
      }
    }));
  }
  function errorType(error) {
    switch (error.name) {
     case "AbortError":
     case "NotAllowedError":
      return "cancelled";

     case "InvalidStateError":
      return "duplicate";

     default:
      return "error";
    }
  }
  function showError(component, type) {
    const el = component.querySelector(`[data-passkey-error="${type}"]`);
    if (el) el.hidden = false;
  }
  function hideErrors(component) {
    for (const el of component.querySelectorAll("[data-passkey-error]")) el.hidden = true;
  }
  function passkeysAvailable() {
    return !!window.PublicKeyCredential;
  }
  async function refreshChallenge(options, challengeUrl, purpose) {
    if (!challengeUrl) throw new Error("Missing passkey challenge URL");
    const body = new URLSearchParams;
    if (purpose) body.append("purpose", purpose);
    const response = await fetch(challengeUrl, {
      method: "POST",
      headers: {
        Accept: "application/json"
      },
      body: body
    });
    if (!response.ok) throw new Error("Failed to refresh challenge");
    const {challenge: challenge} = await response.json();
    options.challenge = challenge;
  }
  function fillRegistrationForm(form, passkey) {
    form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json;
    form.querySelector('[data-passkey-field="attestation_object"]').value = passkey.attestation_object;
    const template = form.querySelector('[data-passkey-field="transports"]');
    for (const transport of passkey.transports) {
      const input = template.cloneNode();
      input.value = transport;
      template.before(input);
    }
    template.remove();
  }
  function fillSignInForm(form, passkey) {
    form.querySelector('[data-passkey-field="id"]').value = passkey.id;
    form.querySelector('[data-passkey-field="client_data_json"]').value = passkey.client_data_json;
    form.querySelector('[data-passkey-field="authenticator_data"]').value = passkey.authenticator_data;
    form.querySelector('[data-passkey-field="signature"]').value = passkey.signature;
  }
  exports.authenticate = authenticate;
  exports.register = register;
  Object.defineProperty(exports, "__esModule", {
    value: true
  });
}));
