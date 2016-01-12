# An evented subscription is created through the ActionCable.Subscriptions instance available on the consumer.
# It provides an extension to standard ActionCable.Subscription class by exposing a basic event handler to
# to trigger client side events using server method calls.
#
# When using an EventedSubscription the `@received` method must not be implemented (if so it will be overwritten).
#
# An example demonstrates the basic functionality:
#
#   App.appearance = App.cable.subscriptions.createEvented "AppearanceChannel",
#     connected: ->
#       # Called once the subscription has been successfully completed
#       @on 'user_appeared', @showUserBadge
#
#     showUserBadge: (badge)->
#       # arguments are provided server side
#       jQuery('#badges').append(badge)
#
#
#   # Callbacks can be registered outside channel building, using inline callbacks
#   jQuery ->
#     App.appearance.on 'user_connected', (user_id)->
#       console.debug "User #{user_id} connected"
#     App.appearance.on 'user_disconnected', (user_id)->
#       console.debug "User #{user_id} disconnected"
#
#   # Finally callbacks can be removed for whatever reason using .off method
#   App.appearance.off 'user_connected' # Remove all event handlers for 'user_connected' event
#
# With evented subscriptions events can be triggered server side with a nice DSL that is automatically translated to
# javascript events.
#
# This is how the server component would look with EventedSubscription:
#
#   class AppearanceChannel < ApplicationActionCable::Channel
#     def subscribed
#       stream_from 'user_events' # Every client will subscribe on user events on connection
#       broadcast_to('user_events').user_connected(current_user.id) # Notify all users of connection
#     end
#   end
#
# When broadcasting needs some intensive task (e.g. a heavy partial rendering) a background task might be a better choice
#
#   def perform(user)
#     template = UsersController.render(partial: 'users/badge', locals: { user: user }
#     AppearanceChannel.broadcast_to('user_events').user_appeared(template)
#   end
#
class ActionCable.EventedSubscription extends ActionCable.Subscription

  # Install an event handler for a named event
  on: (eventName, callback)->
    @eventsFor(eventName).push(callback)

  # Remove all event handlers for a given event
  off: (eventName)->
    delete @__managed_events[eventName] # Reset callback for this event

  # Private API

  # Implementation for client side events. Server side an event payload is built and this method unwrap it and trigger
  # registered event handlers for the named event
  received: (eventPayload) ->
    # Called server side with MyChannel.broadcast_to(channel_name).some_event(args)
    args = [eventPayload.event_name].concat eventPayload.args
    @trigger.apply(this, args)

  # Event dispatcher for named events
  trigger: (eventName, args...)->
    # Invoke registered callbacks for the given event if any
    cb.apply(this, args) for cb in @eventsFor(eventName) if @eventsFor(eventName).length

  # Utility function to retrieve callbacks for a named event
  eventsFor: (eventName)->
    @__managed_events ||= {}
    @__managed_events[eventName] ||= []
