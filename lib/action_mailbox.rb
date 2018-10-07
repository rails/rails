require "action_mailbox/engine"

module ActionMailbox
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Router
  autoload :Callbacks
  autoload :Routing

  mattr_accessor :logger
  mattr_accessor :incinerate_after, default: 30.days
end
