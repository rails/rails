require "action_mailbox/engine"

module ActionMailbox
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Router
  autoload :Callbacks
  autoload :Routing
end
