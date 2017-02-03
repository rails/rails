App.<%= class_name.underscore %> = App.cable.subscriptions.create("<%= class_name %>Channel", {
  connected: function() {
    // Called when the subscription is ready for use on the server
  },

  disconnected: function() {
    // Called when the subscription has been terminated by the server
  },

  received: function(data) {
    // Called when there's incoming data on the websocket for this channel
  }<%= actions.any? ? ",\n" : '' %>
<% actions.each do |action| -%>
  <%=action %>: function() {
    return this.perform('<%= action %>');
  }<%= action == actions[-1] ? '' : ",\n" %>
<% end -%>
});
