const m = Element.prototype.matches ||
    Element.prototype.matchesSelector ||
    Element.prototype.mozMatchesSelector ||
    Element.prototype.msMatchesSelector ||
    Element.prototype.oMatchesSelector ||
    Element.prototype.webkitMatchesSelector

// Checks if the given native dom element matches the selector
// element::
//   native DOM element
// selector::
//   CSS selector string or
//   a JavaScript object with `selector` and `exclude` properties
//   Examples: "form", { selector: "form", exclude: "form[data-remote='true']"}
const matches = function(element, selector) {
  if (selector.exclude) {
    return m.call(element, selector.selector) && !m.call(element, selector.exclude)
  } else {
    return m.call(element, selector)
  }
}

// get and set data on a given element using "expando properties"
// See: https://developer.mozilla.org/en-US/docs/Glossary/Expando
const EXPANDO = "_ujsData"

const getData = (element, key) => element[EXPANDO] ? element[EXPANDO][key] : undefined

const setData = function(element, key, value) {
  if (!element[EXPANDO]) { element[EXPANDO] = {} }
  return element[EXPANDO][key] = value
}

// a wrapper for document.querySelectorAll
// returns an Array
const $ = selector => Array.prototype.slice.call(document.querySelectorAll(selector))

export { matches, getData, setData, $ }
