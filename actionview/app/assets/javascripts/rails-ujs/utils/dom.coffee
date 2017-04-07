m = Element.prototype.matches or
    Element.prototype.matchesSelector or
    Element.prototype.mozMatchesSelector or
    Element.prototype.msMatchesSelector or
    Element.prototype.oMatchesSelector or
    Element.prototype.webkitMatchesSelector

Rails.matches = (element, selector) ->
  if selector.exclude?
    m.call(element, selector.selector) and not m.call(element, selector.exclude)
  else
    m.call(element, selector)

# get and set data on a given element using "expando properties"
# See: https://developer.mozilla.org/en-US/docs/Glossary/Expando
expando = '_ujsData'

Rails.getData = (element, key) ->
  element[expando]?[key]

Rails.setData = (element, key, value) ->
  element[expando] ?= {}
  element[expando][key] = value

# a wrapper for document.querySelectorAll
# returns an Array
Rails.$ = (selector) ->
  Array.prototype.slice.call(document.querySelectorAll(selector))
