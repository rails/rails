#= require ./dom

{ matches } = Rails

# Polyfill for CustomEvent in IE9+
# https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/CustomEvent#Polyfill
CustomEvent = window.CustomEvent

if typeof CustomEvent isnt 'function'
  CustomEvent = (event, params) ->
    evt = document.createEvent('CustomEvent')
    evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail)
    evt
  CustomEvent.prototype = window.Event.prototype

# Triggers a custom event on an element and returns false if the event result is false
fire = Rails.fire = (obj, name, data) ->
  event = new CustomEvent(
    name,
    bubbles: true,
    cancelable: true,
    detail: data,
  )
  obj.dispatchEvent(event)
  !event.defaultPrevented

# Helper function, needed to provide consistent behavior in IE
Rails.stopEverything = (e) ->
  fire(e.target, 'ujs:everythingStopped')
  e.preventDefault()
  e.stopPropagation()
  e.stopImmediatePropagation()

Rails.delegate = (element, selector, eventType, handler) ->
  element.addEventListener eventType, (e) ->
    target = e.target
    target = target.parentNode until not (target instanceof Element) or matches(target, selector)
    if target instanceof Element and handler.call(target, e) == false
      e.preventDefault()
      e.stopPropagation()
