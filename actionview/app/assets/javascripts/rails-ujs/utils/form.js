/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require ./dom

const { matches } = Rails;

const toArray = e => Array.prototype.slice.call(e);

Rails.serializeElement = function(element, additionalParam) {
  let inputs = [element];
  if (matches(element, 'form')) { inputs = toArray(element.elements); }
  const params = [];

  inputs.forEach(function(input) {
    if (!input.name || input.disabled) { return; }
    if (matches(input, 'select')) {
      return toArray(input.options).forEach(function(option) {
        if (option.selected) { return params.push({name: input.name, value: option.value}); }
      });
    } else if (input.checked || (['radio', 'checkbox', 'submit'].indexOf(input.type) === -1)) {
      return params.push({name: input.name, value: input.value});
    }
  });

  if (additionalParam) { params.push(additionalParam); }

  return params.map(function(param) {
    if (param.name != null) {
      return `${encodeURIComponent(param.name)}=${encodeURIComponent(param.value)}`;
    } else {
      return param;
    }}).join('&');
};

// Helper function that returns form elements that match the specified CSS selector
// If form is actually a "form" element this will return associated elements outside the from that have
// the html form attribute set
Rails.formElements = function(form, selector) {
  if (matches(form, 'form')) {
    return toArray(form.elements).filter(el => matches(el, selector));
  } else {
    return toArray(form.querySelectorAll(selector));
  }
};
