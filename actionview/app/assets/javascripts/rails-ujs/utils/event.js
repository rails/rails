/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require ./dom

let preventDefault;
const { matches } = Rails;

// Polyfill for CustomEvent in IE9+
// https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/CustomEvent#Polyfill
let { CustomEvent } = window;

if (typeof CustomEvent !== 'function') {
  CustomEvent = function(event, params) {
    const evt = document.createEvent('CustomEvent');
    evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail);
    return evt;
  };

  CustomEvent.prototype = window.Event.prototype;

  // Fix setting `defaultPrevented` when `preventDefault()` is called
  // http://stackoverflow.com/questions/23349191/event-preventdefault-is-not-working-in-ie-11-for-custom-events
  ({ preventDefault } = CustomEvent.prototype);
  CustomEvent.prototype.preventDefault = function() {
    const result = preventDefault.call(this);
    if (this.cancelable && !this.defaultPrevented) {
      Object.defineProperty(this, 'defaultPrevented', {get() { return true; }});
    }
    return result;
  };
}

// Triggers a custom event on an element and returns false if the event result is false
// obj::
//   a native DOM element
// name::
//   string that corrspends to the event you want to trigger
//   e.g. 'click', 'submit'
// data::
//   data you want to pass when you dispatch an event
const fire = (Rails.fire = function(obj, name, data) {
  const event = new CustomEvent(
    name, {
    bubbles: true,
    cancelable: true,
    detail: data
  }
  );
  obj.dispatchEvent(event);
  return !event.defaultPrevented;
});

// Helper function, needed to provide consistent behavior in IE
Rails.stopEverything = function(e) {
  fire(e.target, 'ujs:everythingStopped');
  e.preventDefault();
  e.stopPropagation();
  return e.stopImmediatePropagation();
};

// Delegates events
// to a specified parent `element`, which fires event `handler`
// for the specified `selector` when an event of `eventType` is triggered
// element::
//   parent element that will listen for events e.g. document
// selector::
//   css selector; or an object that has `selector` and `exclude` properties (see: Rails.matches)
// eventType::
//   string representing the event e.g. 'submit', 'click'
// handler::
//   the event handler to be called
Rails.delegate = (element, selector, eventType, handler) =>
  element.addEventListener(eventType, function(e) {
    let { target } = e;
    while (!!(target instanceof Element) && !matches(target, selector)) { target = target.parentNode; }
    if (target instanceof Element && (handler.call(target, e) === false)) {
      e.preventDefault();
      return e.stopPropagation();
    }
  })
;
