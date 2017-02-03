App.<%= class_name.underscore %> = App.cable.subscriptions.create "<%= class_name %>Channel",
  connected: ->
    # Called when the subscription is ready for use on the server

  disconnected: ->
    # Called when the subscription has been terminated by the server

  received: (data) ->
    # Called when there's incoming data on the websocket for this channel
<% actions.each do |action| -%>

  <%= action %>: ->
    @perform '<%= action %>'
<% end -%>
