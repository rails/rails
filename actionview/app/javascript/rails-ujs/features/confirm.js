import { fire, stopEverything } from "../utils/event"

const handleConfirmWithRails = (rails) => function(e) {
  if (!allowAction(this, rails)) { stopEverything(e) }
}

// Default confirm dialog, may be overridden with custom confirm dialog in Rails.confirm
const confirm = (message, element) => window.confirm(message)

// For 'data-confirm' attribute:
// - Fires `confirm` event
// - Shows the confirmation dialog
// - Fires the `confirm:complete` event
//
// Returns `true` if no function stops the chain and user chose yes `false` otherwise.
// Attaching a handler to the element's `confirm` event that returns a `falsy` value cancels the confirmation dialog.
// Attaching a handler to the element's `confirm:complete` event that returns a `falsy` value makes this function
// return false. The `confirm:complete` event is fired whether or not the user answered true or false to the dialog.
var allowAction = function(element, rails) {
  let callback
  const message = element.getAttribute("data-confirm")
  if (!message) { return true }

  let answer = false
  if (fire(element, "confirm")) {
    try { answer = rails.confirm(message, element) } catch(error) { /* do nothing */ }
    callback = fire(element, "confirm:complete", [answer])
  }

  return answer && callback
}

export { handleConfirmWithRails, confirm }
