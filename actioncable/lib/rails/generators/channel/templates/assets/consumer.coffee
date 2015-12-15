#= require cable
#= require_self
#= require ./channels

@App = {}
App.cable = Cable.createConsumer()
