#= require ./dom

{ matches } = Rails

toArray = (e) -> Array.prototype.slice.call(e)

Rails.serializeElement = (element, additionalParam) ->
  inputs = [element]
  inputs = toArray(element.elements) if matches(element, 'form')
  params = []

  inputs.forEach (input) ->
    return unless input.name
    if matches(input, 'select')
      toArray(input.options).forEach (option) ->
        params.push(name: input.name, value: option.value) if option.selected
    else if input.checked or ['radio', 'checkbox', 'submit'].indexOf(input.type) == -1
      params.push(name: input.name, value: input.value)

  params.push(additionalParam) if additionalParam

  params.map (param) ->
    if param.name?
      "#{encodeURIComponent(param.name)}=#{encodeURIComponent(param.value)}"
    else
      param
  .join('&')

# Helper function that returns form elements that match the specified CSS selector
# If form is actually a "form" element this will return associated elements outside the from that have
# the html form attribute set
Rails.formElements = (form, selector) ->
  if matches(form, 'form')
    toArray(form.elements).filter (el) -> matches(el, selector)
  else
    toArray(form.querySelectorAll(selector))
