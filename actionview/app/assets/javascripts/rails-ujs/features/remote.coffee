#= require_tree ../utils

{
  matches, getData, setData
  fire, stopEverything
  ajax, isCrossDomain
  serializeElement
} = Rails

# Checks "data-remote" if true to handle the request through a XHR request.
isRemote = (element) ->
  value = element.getAttribute('data-remote')
  value? and value isnt 'false'

# Submits "remote" forms and links with ajax
Rails.handleRemote = (e) ->
  element = this

  return true unless isRemote(element)
  unless fire(element, 'ajax:before')
    fire(element, 'ajax:stopped')
    return false

  withCredentials = element.getAttribute('data-with-credentials')
  dataType = element.getAttribute('data-type') or 'script'

  if matches(element, Rails.formSubmitSelector)
    # memoized value from clicked submit button
    button = getData(element, 'ujs:submit-button')
    method = getData(element, 'ujs:submit-button-formmethod') or element.method
    url = getData(element, 'ujs:submit-button-formaction') or element.getAttribute('action') or location.href

    # strip query string if it's a GET request
    url = url.replace(/\?.*$/, '') if method.toUpperCase() is 'GET'

    if element.enctype is 'multipart/form-data'
      data = new FormData(element)
      data.append(button.name, button.value) if button?
    else
      data = serializeElement(element, button)

    setData(element, 'ujs:submit-button', null)
    setData(element, 'ujs:submit-button-formmethod', null)
    setData(element, 'ujs:submit-button-formaction', null)
  else if matches(element, Rails.buttonClickSelector) or matches(element, Rails.inputChangeSelector)
    method = element.getAttribute('data-method')
    url = element.getAttribute('data-url')
    data = serializeElement(element, element.getAttribute('data-params'))
  else
    method = element.getAttribute('data-method')
    url = Rails.href(element)
    data = element.getAttribute('data-params')

  ajax(
    type: method or 'GET'
    url: url
    data: data
    dataType: dataType
    # stopping the "ajax:beforeSend" event will cancel the ajax request
    beforeSend: (xhr, options) ->
      if fire(element, 'ajax:beforeSend', [xhr, options])
        fire(element, 'ajax:send', [xhr])
      else
        fire(element, 'ajax:stopped')
        return false
    success: (args...) -> fire(element, 'ajax:success', args)
    error: (args...) -> fire(element, 'ajax:error', args)
    complete: (args...) -> fire(element, 'ajax:complete', args)
    crossDomain: isCrossDomain(url)
    withCredentials: withCredentials? and withCredentials isnt 'false'
  )
  stopEverything(e)

Rails.formSubmitButtonClick = (e) ->
  button = this
  form = button.form
  return unless form
  # Register the pressed submit button
  setData(form, 'ujs:submit-button', name: button.name, value: button.value) if button.name
  # Save attributes from button
  setData(form, 'ujs:formnovalidate-button', button.formNoValidate)
  setData(form, 'ujs:submit-button-formaction', button.getAttribute('formaction'))
  setData(form, 'ujs:submit-button-formmethod', button.getAttribute('formmethod'))

Rails.handleMetaClick = (e) ->
  link = this
  method = (link.getAttribute('data-method') or 'GET').toUpperCase()
  data = link.getAttribute('data-params')
  metaClick = e.metaKey or e.ctrlKey
  e.stopImmediatePropagation() if metaClick and method is 'GET' and not data
