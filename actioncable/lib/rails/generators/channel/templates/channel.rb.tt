# Be sure to restart your server when you modify this file. Action Cable runs in a loop that does not support auto reloading.
<% module_namespacing do -%>
class <%= class_name %>Channel < ApplicationCable::Channel
  def subscribed
    # stream_from "some_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
<% actions.each do |action| -%>

  def <%= action %>
  end
<% end -%>
end
<% end -%>
