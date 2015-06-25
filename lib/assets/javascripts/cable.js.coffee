#= require_self
#= require cable/consumer

@Cable =
  PING_IDENTIFIER: "_ping"

  createConsumer: (url) ->
    new Cable.Consumer url
