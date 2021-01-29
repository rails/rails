#= require ./csp
#= require ./csrf
#= require ./event

{ cspNonce, CSRFProtection, fire } = Rails

AcceptHeaders =
  '*': '*/*'
  text: 'text/plain'
  html: 'text/html'
  xml: 'application/xml, text/xml'
  json: 'application/json, text/javascript'
  script: 'text/javascript, application/javascript, application/ecmascript, application/x-ecmascript'

Rails.ajax = (options) ->
  options = prepareOptions(options)
  xhr = createXHR options, ->
    response = processResponse(xhr.response ? xhr.responseText, xhr.getResponseHeader('Content-Type'))
    if xhr.status // 100 == 2
      options.success?(response, xhr.statusText, xhr)
    else
      options.error?(response, xhr.statusText, xhr)
    options.complete?(xhr, xhr.statusText)

  if options.beforeSend? && !options.beforeSend(xhr, options)
    return false

  if xhr.readyState is XMLHttpRequest.OPENED
    xhr.send(options.data)

prepareOptions = (options) ->
  options.url = options.url or location.href
  options.type = options.type.toUpperCase()
  # append data to url if it's a GET request
  if options.type is 'GET' and options.data
    if options.url.indexOf('?') < 0
      options.url += '?' + options.data
    else
      options.url += '&' + options.data
  # Use "*" as default dataType
  options.dataType = '*' unless AcceptHeaders[options.dataType]?
  options.accept = AcceptHeaders[options.dataType]
  options.accept += ', */*; q=0.01' if options.dataType isnt '*'
  options

createXHR = (options, done) ->
  xhr = new XMLHttpRequest()
  # Open and set up xhr
  xhr.open(options.type, options.url, true)
  xhr.setRequestHeader('Accept', options.accept)
  # Set Content-Type only when sending a string
  # Sending FormData will automatically set Content-Type to multipart/form-data
  if typeof options.data is 'string'
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8')
  unless options.crossDomain
    xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
    # Add X-CSRF-Token
    CSRFProtection(xhr)
  xhr.withCredentials = !!options.withCredentials
  xhr.onreadystatechange = ->
    done(xhr) if xhr.readyState is XMLHttpRequest.DONE
  xhr

processResponse = (response, type) ->
  if typeof response is 'string' and typeof type is 'string'
    if type.match(/\bjson\b/)
      try response = JSON.parse(response)
    else if type.match(/\b(?:java|ecma)script\b/)
      script = document.createElement('script')
      script.setAttribute('nonce', cspNonce())
      script.text = response
      document.head.appendChild(script).parentNode.removeChild(script)
    else if type.match(/\b(xml|html|svg)\b/)
      parser = new DOMParser()
      type = type.replace(/;.+/, '') # remove something like ';charset=utf-8'
      try response = parser.parseFromString(response, type)
  response

# Default way to get an element's href. May be overridden at Rails.href.
Rails.href = (element) -> element.href

# Determines if the request is a cross domain request.
Rails.isCrossDomain = (url) ->
  originAnchor = document.createElement('a')
  originAnchor.href = location.href
  urlAnchor = document.createElement('a')
  try
    urlAnchor.href = url
    # If URL protocol is false or is a string containing a single colon
    # *and* host are false, assume it is not a cross-domain request
    # (should only be the case for IE7 and IE compatibility mode).
    # Otherwise, evaluate protocol and host of the URL against the origin
    # protocol and host.
    !(((!urlAnchor.protocol || urlAnchor.protocol == ':') && !urlAnchor.host) ||
      (originAnchor.protocol + '//' + originAnchor.host == urlAnchor.protocol + '//' + urlAnchor.host))
  catch e
    # If there is an error parsing the URL, assume it is crossDomain.
    true
