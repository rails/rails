const toArray = e => Array.prototype.slice.call(e)

const serializeElement = (element, additionalParam) => {
  let inputs = [element]
  if (element.matches("form")) { inputs = toArray(element.elements) }
  const params = []

  inputs.forEach(function(input) {
    if (!input.name || input.disabled) { return }
    if (input.matches("fieldset[disabled] *")) { return }
    if (input.matches("select")) {
      toArray(input.options).forEach(function(option) {
        if (option.selected) { params.push({name: input.name, value: option.value}) }
      })
    } else if (input.checked || (["radio", "checkbox", "submit"].indexOf(input.type) === -1)) {
      params.push({name: input.name, value: input.value})
    }
  })

  if (additionalParam) { params.push(additionalParam) }

  return params.map(function(param) {
    if (param.name) {
      return `${encodeURIComponent(param.name)}=${encodeURIComponent(param.value)}`
    } else {
      return param
    }}).join("&")
}

// Helper function that returns form elements that match the specified CSS selector
// If form is actually a "form" element this will return associated elements outside the from that have
// the HTML form attribute set
const formElements = (form, selector) => {
  if (form.matches("form")) {
    return toArray(form.elements).filter(el => el.matches(selector))
  } else {
    return toArray(form.querySelectorAll(selector))
  }
}

export { serializeElement, formElements }
