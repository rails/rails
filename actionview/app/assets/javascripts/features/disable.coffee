#= require_tree ../utils

{ matches, getData, setData, stopEverything, formElements } = Rails

# Unified function to enable an element (link, button and form)
Rails.enableElement = (e) ->
  element = if e instanceof Event then e.target else e
  if matches(element, Rails.linkDisableSelector)
    enableLinkElement(element)
  else if matches(element, Rails.buttonDisableSelector) or matches(element, Rails.formEnableSelector)
    enableFormElement(element)
  else if matches(element, Rails.formSubmitSelector)
    enableFormElements(element)

# Unified function to disable an element (link, button and form)
Rails.disableElement = (e) ->
  element = if e instanceof Event then e.target else e
  if matches(element, Rails.linkDisableSelector)
    disableLinkElement(element)
  else if matches(element, Rails.buttonDisableSelector) or matches(element, Rails.formDisableSelector)
    disableFormElement(element)
  else if matches(element, Rails.formSubmitSelector)
    disableFormElements(element)

#  Replace element's html with the 'data-disable-with' after storing original html
#  and prevent clicking on it
disableLinkElement = (element) ->
  replacement = element.getAttribute('data-disable-with')
  if replacement?
    setData(element, 'ujs:enable-with', element.innerHTML) # store enabled state
    element.innerHTML = replacement
  element.addEventListener('click', stopEverything) # prevent further clicking
  setData(element, 'ujs:disabled', true)

# Restore element to its original state which was disabled by 'disableLinkElement' above
enableLinkElement = (element) ->
  originalText = getData(element, 'ujs:enable-with')
  if originalText?
    element.innerHTML = originalText # set to old enabled state
    setData(element, 'ujs:enable-with', null) # clean up cache
  element.removeEventListener('click', stopEverything) # enable element
  setData(element, 'ujs:disabled', null)

# Disables form elements:
#  - Caches element value in 'ujs:enable-with' data store
#  - Replaces element text with value of 'data-disable-with' attribute
#  - Sets disabled property to true
disableFormElements = (form) ->
  formElements(form, Rails.formDisableSelector).forEach(disableFormElement)

disableFormElement = (element) ->
  replacement = element.getAttribute('data-disable-with')
  if replacement?
    if matches(element, 'button')
      setData(element, 'ujs:enable-with', element.innerHTML)
      element.innerHTML = replacement
    else
      setData(element, 'ujs:enable-with', element.value)
      element.value = replacement
  element.disabled = true
  setData(element, 'ujs:disabled', true)

# Re-enables disabled form elements:
#  - Replaces element text with cached value from 'ujs:enable-with' data store (created in `disableFormElements`)
#  - Sets disabled property to false
enableFormElements = (form) ->
  formElements(form, Rails.formEnableSelector).forEach(enableFormElement)

enableFormElement = (element) ->
  originalText = getData(element, 'ujs:enable-with')
  if originalText?
    if matches(element, 'button')
      element.innerHTML = originalText
    else
      element.value = originalText
    setData(element, 'ujs:enable-with', null) # clean up cache
  element.disabled = false
  setData(element, 'ujs:disabled', null)
