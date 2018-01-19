export function getMetaValue(name) {
  const element = findElement(document.head, `meta[name="${name}"]`)
  if (element) {
    return element.getAttribute("content")
  }
}

export function findElements(root, selector) {
  if (typeof root == "string") {
    selector = root
    root = document
  }
  const elements = root.querySelectorAll(selector)
  return toArray(elements)
}

export function findElement(root, selector) {
  if (typeof root == "string") {
    selector = root
    root = document
  }
  return root.querySelector(selector)
}

export function dispatchEvent(element, type, eventInit = {}) {
  const { disabled } = element
  const { bubbles, cancelable, detail } = eventInit
  const event = document.createEvent("Event")

  event.initEvent(type, bubbles || true, cancelable || true)
  event.detail = detail || {}

  try {
    element.disabled = false
    element.dispatchEvent(event)
  } finally {
    element.disabled = disabled
  }

  return event
}

export function toArray(value) {
  if (Array.isArray(value)) {
    return value
  } else if (Array.from) {
    return Array.from(value)
  } else {
    return [].slice.call(value)
  }
}
