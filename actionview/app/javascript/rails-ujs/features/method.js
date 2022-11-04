import { isCrossDomain } from "../utils/ajax"
import * as csrf from "../utils/csrf"
import { stopEverything } from "../utils/event"

// Handles "data-method" on links such as:
// <a href="/users/5" data-method="delete" rel="nofollow" data-confirm="Are you sure?">Delete</a>
const handleMethodWithRails = (rails) => function(e) {
  const link = this
  const method = link.getAttribute("data-method")
  if (!method) { return }

  const href = rails.href(link)
  const csrfToken = csrf.csrfToken()
  const csrfParam = csrf.csrfParam()
  const form = document.createElement("form")
  let formContent = `<input name='_method' value='${method}' type='hidden' />`

  if (csrfParam && csrfToken && !isCrossDomain(href)) {
    formContent += `<input name='${csrfParam}' value='${csrfToken}' type='hidden' />`
  }

  // Must trigger submit by click on a button, else "submit" event handler won't work!
  // https://developer.mozilla.org/en-US/docs/Web/API/HTMLFormElement/submit
  formContent += "<input type=\"submit\" />"

  form.method = "post"
  form.action = href
  form.target = link.target
  form.innerHTML = formContent
  form.style.display = "none"

  document.body.appendChild(form)
  form.querySelector("[type=\"submit\"]").click()

  stopEverything(e)
}

export { handleMethodWithRails }
