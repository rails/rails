#= require action_cable
#= require_self
#= require_tree ./channels

@App ||= {}
App.cable = ActionCable.createConsumer()
