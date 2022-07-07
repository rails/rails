import { formSubmitSelector, buttonClickSelector, inputChangeSelector } from "../utils/constants"
import { ajax, isCrossDomain } from "../utils/ajax"
import { matches, getData, setData } from "../utils/dom"
import { fire, stopEverything } from "../utils/event"
import { serializeElement } from "../utils/form"

// Checks "data-remote" if true to handle the request through a XHR request.
const isRemote = function(element) {
  const value = element.getAttribute("data-remote")
  return (value != null) && (value !== "false")
}

// Submits "remote" forms and links with ajax
const handleRemoteWithRails = (rails) => function(e) {
  let data, method, url
  const element = this

  if (!isRemote(element)) { return true }
  if (!fire(element, "ajax:before")) {
    fire(element, "ajax:stopped")
    return false
  }

  const withCredentials = element.getAttribute("data-with-credentials")
  const dataType = element.getAttribute("data-type") || "script"

  if (matches(element, formSubmitSelector)) {
    // memoized value from clicked submit button
    const button = getData(element, "ujs:submit-button")
    method = getData(element, "ujs:submit-button-formmethod") || element.getAttribute("method") || "get"
    url = getData(element, "ujs:submit-button-formaction") || element.getAttribute("action") || location.href

    // strip query string if it's a GET request
    if (method.toUpperCase() === "GET") { url = url.replace(/\?.*$/, "") }

    if (element.enctype === "multipart/form-data") {
      data = new FormData(element)
      if (button != null) { data.append(button.name, button.value) }
    } else {
      data = serializeElement(element, button)
    }

    setData(element, "ujs:submit-button", null)
    setData(element, "ujs:submit-button-formmethod", null)
    setData(element, "ujs:submit-button-formaction", null)
  } else if (matches(element, buttonClickSelector) || matches(element, inputChangeSelector)) {
    method = element.getAttribute("data-method")
    url = element.getAttribute("data-url")
    data = serializeElement(element, element.getAttribute("data-params"))
  } else {
    method = element.getAttribute("data-method")
    url = rails.href(element)
    data = element.getAttribute("data-params")
  }

  ajax({
    type: method || "GET",
    url,
    data,
    dataType,
    // stopping the "ajax:beforeSend" event will cancel the ajax request
    beforeSend(xhr, options) {
      if (fire(element, "ajax:beforeSend", [xhr, options])) {
        return fire(element, "ajax:send", [xhr])
      } else {
        fire(element, "ajax:stopped")
        return false
      }
    },
    success(...args) { return fire(element, "ajax:success", args) },
    error(...args) { return fire(element, "ajax:error", args) },
    complete(...args) { return fire(element, "ajax:complete", args) },
    crossDomain: isCrossDomain(url),
    withCredentials: (withCredentials != null) && (withCredentials !== "false")
  })
  stopEverything(e)
}

const formSubmitButtonClick = function(e) {
  const button = this
  const {
    form
  } = button
  if (!form) { return }
  // Register the pressed submit button
  if (button.name) { setData(form, "ujs:submit-button", {name: button.name, value: button.value}) }
  // Save attributes from button
  setData(form, "ujs:formnovalidate-button", button.formNoValidate)
  setData(form, "ujs:submit-button-formaction", button.getAttribute("formaction"))
  return setData(form, "ujs:submit-button-formmethod", button.getAttribute("formmethod"))
}

const preventInsignificantClick = function(e) {
  const link = this
  const method = (link.getAttribute("data-method") || "GET").toUpperCase()
  const data = link.getAttribute("data-params")
  const metaClick = e.metaKey || e.ctrlKey
  const insignificantMetaClick = metaClick && (method === "GET") && !data
  const nonPrimaryMouseClick = (e.button != null) && (e.button !== 0)
  if (nonPrimaryMouseClick || insignificantMetaClick) { e.stopImmediatePropagation() }
}

export { handleRemoteWithRails, formSubmitButtonClick, preventInsignificantClick }
