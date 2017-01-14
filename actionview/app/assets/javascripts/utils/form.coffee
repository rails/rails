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
    else if input.type isnt 'radio' and input.type isnt 'checkbox' or input.checked
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

# Helper function which checks for blank inputs in a form that match the specified CSS selector
Rails.blankInputs = (form, selector, nonBlank) ->
  foundInputs = []
  requiredInputs = toArray(form.querySelectorAll(selector or 'input, textarea'))
  checkedRadioButtonNames = {}

  requiredInputs.forEach (input) ->
    if input.type is 'radio'
      # Don't count unchecked required radio as blank if other radio with same name is checked,
      # regardless of whether same-name radio input has required attribute or not. The spec
      # states https://www.w3.org/TR/html5/forms.html#the-required-attribute
      radioName = input.name
      # Skip if we've already seen the radio with this name.
      unless checkedRadioButtonNames[radioName]
        # If none checked
        if form.querySelectorAll("input[type=radio][name='#{radioName}']:checked").length == 0
          radios = form.querySelectorAll("input[type=radio][name='#{radioName}']")
          foundInputs = foundInputs.concat(toArray(radios))
        # We only need to check each name once.
        checkedRadioButtonNames[radioName] = radioName
    else
      valueToCheck = if input.type is 'checkbox' then input.checked else !!input.value
      foundInputs.push(input) if valueToCheck is nonBlank
  foundInputs
