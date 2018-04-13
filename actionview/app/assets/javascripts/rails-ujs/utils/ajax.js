/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require ./csp
//= require ./csrf
//= require ./event

const { cspNonce, CSRFProtection, fire } = Rails;

const AcceptHeaders = {
  '*': '*/*',
  text: 'text/plain',
  html: 'text/html',
  xml: 'application/xml, text/xml',
  json: 'application/json, text/javascript',
  script: 'text/javascript, application/javascript, application/ecmascript, application/x-ecmascript'
};

Rails.ajax = function(options) {
  options = prepareOptions(options);
  var xhr = createXHR(options, function() {
    const response = processResponse(xhr.response != null ? xhr.response : xhr.responseText, xhr.getResponseHeader('Content-Type'));
    if (Math.floor(xhr.status / 100) === 2) {
      if (typeof options.success === 'function') {
        options.success(response, xhr.statusText, xhr);
      }
    } else {
      if (typeof options.error === 'function') {
        options.error(response, xhr.statusText, xhr);
      }
    }
    return (typeof options.complete === 'function' ? options.complete(xhr, xhr.statusText) : undefined);
  });

  if ((options.beforeSend != null) && !options.beforeSend(xhr, options)) {
    return false;
  }

  if (xhr.readyState === XMLHttpRequest.OPENED) {
    return xhr.send(options.data);
  }
};

var prepareOptions = function(options) {
  options.url = options.url || location.href;
  options.type = options.type.toUpperCase();
  // append data to url if it's a GET request
  if ((options.type === 'GET') && options.data) {
    if (options.url.indexOf('?') < 0) {
      options.url += `?${options.data}`;
    } else {
      options.url += `&${options.data}`;
    }
  }
  // Use "*" as default dataType
  if (AcceptHeaders[options.dataType] == null) { options.dataType = '*'; }
  options.accept = AcceptHeaders[options.dataType];
  if (options.dataType !== '*') { options.accept += ', */*; q=0.01'; }
  return options;
};

var createXHR = function(options, done) {
  const xhr = new XMLHttpRequest();
  // Open and setup xhr
  xhr.open(options.type, options.url, true);
  xhr.setRequestHeader('Accept', options.accept);
  // Set Content-Type only when sending a string
  // Sending FormData will automatically set Content-Type to multipart/form-data
  if (typeof options.data === 'string') {
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded; charset=UTF-8');
  }
  if (!options.crossDomain) { xhr.setRequestHeader('X-Requested-With', 'XMLHttpRequest'); }
  // Add X-CSRF-Token
  CSRFProtection(xhr);
  xhr.withCredentials = !!options.withCredentials;
  xhr.onreadystatechange = function() {
    if (xhr.readyState === XMLHttpRequest.DONE) { return done(xhr); }
  };
  return xhr;
};

var processResponse = function(response, type) {
  if ((typeof response === 'string') && (typeof type === 'string')) {
    if (type.match(/\bjson\b/)) {
      try { response = JSON.parse(response); } catch (error) {}
    } else if (type.match(/\b(?:java|ecma)script\b/)) {
      const script = document.createElement('script');
      script.nonce = cspNonce();
      script.text = response;
      document.head.appendChild(script).parentNode.removeChild(script);
    } else if (type.match(/\bxml\b/)) {
      const parser = new DOMParser();
      type = type.replace(/;.+/, ''); // remove something like ';charset=utf-8'
      try { response = parser.parseFromString(response, type); } catch (error1) {}
    }
  }
  return response;
};

// Default way to get an element's href. May be overridden at Rails.href.
Rails.href = element => element.href;

// Determines if the request is a cross domain request.
Rails.isCrossDomain = function(url) {
  const originAnchor = document.createElement('a');
  originAnchor.href = location.href;
  const urlAnchor = document.createElement('a');
  try {
    urlAnchor.href = url;
    // If URL protocol is false or is a string containing a single colon
    // *and* host are false, assume it is not a cross-domain request
    // (should only be the case for IE7 and IE compatibility mode).
    // Otherwise, evaluate protocol and host of the URL against the origin
    // protocol and host.
    return !(((!urlAnchor.protocol || (urlAnchor.protocol === ':')) && !urlAnchor.host) ||
      ((originAnchor.protocol + '//' + originAnchor.host) === (urlAnchor.protocol + '//' + urlAnchor.host)));
  } catch (e) {
    // If there is an error parsing the URL, assume it is crossDomain.
    return true;
  }
};
