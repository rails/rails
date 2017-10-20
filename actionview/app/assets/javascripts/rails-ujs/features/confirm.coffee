#= require_tree ../utils

{ fire, stopEverything } = Rails

Rails.handleConfirm = (e) ->
  stopEverything(e) unless allowAction(this)

# For 'data-confirm' attribute:
# - Fires `confirm` event
# - Shows the confirmation dialog
# - Fires the `confirm:complete` event
#
# Returns `true` if no function stops the chain and user chose yes `false` otherwise.
# Attaching a handler to the element's `confirm` event that returns a `falsy` value cancels the confirmation dialog.
# Attaching a handler to the element's `confirm:complete` event that returns a `falsy` value makes this function
# return false. The `confirm:complete` event is fired whether or not the user answered true or false to the dialog.
allowAction = (element) ->
  message = element.getAttribute('data-confirm')
  return true unless message

  answer = false
  if fire(element, 'confirm')
    try answer = confirm(message)
    callback = fire(element, 'confirm:complete', [answer])

  answer and callback
