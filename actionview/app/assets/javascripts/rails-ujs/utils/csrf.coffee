#= require ./dom

{ $ } = Rails

# Up-to-date Cross-Site Request Forgery token
csrfToken = Rails.csrfToken = ->
  meta = document.querySelector('meta[name=csrf-token]')
  meta and meta.content

# URL param that must contain the CSRF token
csrfParam = Rails.csrfParam = ->
  meta = document.querySelector('meta[name=csrf-param]')
  meta and meta.content

# Make sure that every Ajax request sends the CSRF token
Rails.CSRFProtection = (xhr) ->
  token = csrfToken()
  xhr.setRequestHeader('X-CSRF-Token', token) if token?

# Make sure that all forms have actual up-to-date tokens (cached forms contain old ones)
Rails.refreshCSRFTokens = ->
  token = csrfToken()
  param = csrfParam()
  if token? and param?
    $('form input[name="' + param + '"]').forEach (input) -> input.value = token
