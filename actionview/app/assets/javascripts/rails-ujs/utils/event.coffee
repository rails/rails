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

  # Fix setting `defaultPrevented` when `preventDefault()` is called
  # http://stackoverflow.com/questions/23349191/event-preventdefault-is-not-working-in-ie-11-for-custom-events
  { preventDefault } = CustomEvent.prototype
  CustomEvent.prototype.preventDefault = ->
    result = preventDefault.call(this)
    if @cancelable and not @defaultPrevented
      Object.defineProperty(this, 'defaultPrevented', get: -> true)
    result

# Triggers a custom event on an element and returns false if the event result is false
# obj::
#   a native DOM element
# name::
#   string that corresponds to the event you want to trigger
#   e.g. 'click', 'submit'
# data::
#   data you want to pass when you dispatch an event
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

# Delegates events
# to a specified parent `element`, which fires event `handler`
# for the specified `selector` when an event of `eventType` is triggered
# element::
#   parent element that will listen for events e.g. document
# selector::
#   CSS selector; or an object that has `selector` and `exclude` properties (see: Rails.matches)
# eventType::
#   string representing the event e.g. 'submit', 'click'
# handler::
#   the event handler to be called
Rails.delegate = (element, selector, eventType, handler) ->
  element.addEventListener eventType, (e) ->
    target = e.target
    target = target.parentNode until not (target instanceof Element) or matches(target, selector)
    if target instanceof Element and handler.call(target, e) == false
      e.preventDefault()
      e.stopPropagation()
