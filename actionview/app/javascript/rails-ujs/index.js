import {
  linkClickSelector,
  buttonClickSelector,
  inputChangeSelector,
  formSubmitSelector,
  formInputClickSelector,
  formDisableSelector,
  formEnableSelector,
  fileInputSelector,
  linkDisableSelector,
  buttonDisableSelector
} from "./utils/constants"

import { ajax, href, isCrossDomain } from "./utils/ajax"
import { cspNonce, loadCSPNonce } from "./utils/csp"
import { csrfToken, csrfParam, CSRFProtection, refreshCSRFTokens } from "./utils/csrf"
import { matches, getData, setData, $ } from "./utils/dom"
import { fire, stopEverything, delegate } from "./utils/event"
import { serializeElement, formElements } from "./utils/form"

import { confirm, handleConfirmWithRails } from "./features/confirm"
import { handleDisabledElement, enableElement, disableElement } from "./features/disable"
import { handleMethodWithRails } from "./features/method"
import { handleRemoteWithRails, formSubmitButtonClick, preventInsignificantClick } from "./features/remote"

const Rails = {
  $,
  ajax,
  buttonClickSelector,
  buttonDisableSelector,
  confirm,
  cspNonce,
  csrfToken,
  csrfParam,
  CSRFProtection,
  delegate,
  disableElement,
  enableElement,
  fileInputSelector,
  fire,
  formElements,
  formEnableSelector,
  formDisableSelector,
  formInputClickSelector,
  formSubmitButtonClick,
  formSubmitSelector,
  getData,
  handleDisabledElement,
  href,
  inputChangeSelector,
  isCrossDomain,
  linkClickSelector,
  linkDisableSelector,
  loadCSPNonce,
  matches,
  preventInsignificantClick,
  refreshCSRFTokens,
  serializeElement,
  setData,
  stopEverything
}

// needs to be able to call Rails.confirm in case its overridden
const handleConfirm = handleConfirmWithRails(Rails)
Rails.handleConfirm = handleConfirm

// needs to be able to call Rails.href in case its overridden
const handleMethod = handleMethodWithRails(Rails)
Rails.handleMethod = handleMethod

// needs to be able to call Rails.href in case its overridden
const handleRemote = handleRemoteWithRails(Rails)
Rails.handleRemote = handleRemote

const start = function() {
  // Cut down on the number of issues from people inadvertently including
  // rails-ujs twice by detecting and raising an error when it happens.
  if (window._rails_loaded) { throw new Error("rails-ujs has already been loaded!") }

  // This event works the same as the load event, except that it fires every
  // time the page is loaded.
  // See https://github.com/rails/jquery-ujs/issues/357
  // See https://developer.mozilla.org/en-US/docs/Using_Firefox_1.5_caching
  window.addEventListener("pageshow", function() {
    $(formEnableSelector).forEach(function(el) {
      if (getData(el, "ujs:disabled")) {
        enableElement(el)
      }
    })
    $(linkDisableSelector).forEach(function(el) {
      if (getData(el, "ujs:disabled")) {
        enableElement(el)
      }
    })
  })

  delegate(document, linkDisableSelector, "ajax:complete", enableElement)
  delegate(document, linkDisableSelector, "ajax:stopped", enableElement)
  delegate(document, buttonDisableSelector, "ajax:complete", enableElement)
  delegate(document, buttonDisableSelector, "ajax:stopped", enableElement)

  delegate(document, linkClickSelector, "click", preventInsignificantClick)
  delegate(document, linkClickSelector, "click", handleDisabledElement)
  delegate(document, linkClickSelector, "click", handleConfirm)
  delegate(document, linkClickSelector, "click", disableElement)
  delegate(document, linkClickSelector, "click", handleRemote)
  delegate(document, linkClickSelector, "click", handleMethod)

  delegate(document, buttonClickSelector, "click", preventInsignificantClick)
  delegate(document, buttonClickSelector, "click", handleDisabledElement)
  delegate(document, buttonClickSelector, "click", handleConfirm)
  delegate(document, buttonClickSelector, "click", disableElement)
  delegate(document, buttonClickSelector, "click", handleRemote)

  delegate(document, inputChangeSelector, "change", handleDisabledElement)
  delegate(document, inputChangeSelector, "change", handleConfirm)
  delegate(document, inputChangeSelector, "change", handleRemote)

  delegate(document, formSubmitSelector, "submit", handleDisabledElement)
  delegate(document, formSubmitSelector, "submit", handleConfirm)
  delegate(document, formSubmitSelector, "submit", handleRemote)
  // Normal mode submit
  // Slight timeout so that the submit button gets properly serialized
  delegate(document, formSubmitSelector, "submit", e => setTimeout((() => disableElement(e)), 13))
  delegate(document, formSubmitSelector, "ajax:send", disableElement)
  delegate(document, formSubmitSelector, "ajax:complete", enableElement)

  delegate(document, formInputClickSelector, "click", preventInsignificantClick)
  delegate(document, formInputClickSelector, "click", handleDisabledElement)
  delegate(document, formInputClickSelector, "click", handleConfirm)
  delegate(document, formInputClickSelector, "click", formSubmitButtonClick)

  document.addEventListener("DOMContentLoaded", refreshCSRFTokens)
  document.addEventListener("DOMContentLoaded", loadCSPNonce)
  return window._rails_loaded = true
}
Rails.start = start

// For backward compatibility
if (typeof jQuery !== "undefined" && jQuery && jQuery.ajax) {
  if (jQuery.rails) { throw new Error("If you load both jquery_ujs and rails-ujs, use rails-ujs only.") }
  jQuery.rails = Rails
  jQuery.ajaxPrefilter(function(options, originalOptions, xhr) {
    if (!options.crossDomain) { return CSRFProtection(xhr) }
  })
}

// This block is to maintain backwards compatibility with the existing
// difference between what happens in a bundler and what happens using a
// sprockets compiler. In the sprockets case, Rails.start() is called
// automatically, but it is not in the ESModule case.
if (typeof exports !== "object" && typeof module === "undefined") {
  // The coffeescript bundle would set this at the very top. The Rollup bundle
  // doesn't set this until the entire bundle has finished running, so we need
  // to make sure its set before firing the rails:attachBindings event for
  // backwards compatibility.
  window.Rails = Rails

  if (fire(document, "rails:attachBindings")) {
    start()
  }
}

export default Rails
