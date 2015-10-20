#= require_self
#= require cable/consumer

@Cable =
  PING_IDENTIFIER: "_ping"
  INTERNAL_MESSAGES:
    SUBSCRIPTION_CONFIRMATION: 'confirm_subscription'
    SUBSCRIPTION_REJECTION: 'reject_subscription'

  createConsumer: (url) ->
    new Cable.Consumer url
