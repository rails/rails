#= require action_cable
#= require_self
#= require ./channels

@App ||= {}
App.cable = ActionCable.createConsumer()
