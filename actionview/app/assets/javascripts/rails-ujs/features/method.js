/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
//= require_tree ../utils

const { stopEverything } = Rails;

// Handles "data-method" on links such as:
// <a href="/users/5" data-method="delete" rel="nofollow" data-confirm="Are you sure?">Delete</a>
Rails.handleMethod = function(e) {
  const link = this;
  const method = link.getAttribute('data-method');
  if (!method) { return; }

  const href = Rails.href(link);
  const csrfToken = Rails.csrfToken();
  const csrfParam = Rails.csrfParam();
  const form = document.createElement('form');
  let formContent = `<input name='_method' value='${method}' type='hidden' />`;

  if ((csrfParam != null) && (csrfToken != null) && !Rails.isCrossDomain(href)) {
    formContent += `<input name='${csrfParam}' value='${csrfToken}' type='hidden' />`;
  }

  // Must trigger submit by click on a button, else "submit" event handler won't work!
  // https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/submit
  formContent += '<input type="submit" />';

  form.method = 'post';
  form.action = href;
  form.target = link.target;
  form.innerHTML = formContent;
  form.style.display = 'none';

  document.body.appendChild(form);
  form.querySelector('[type="submit"]').click();

  return stopEverything(e);
};
