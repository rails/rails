require "action_mailroom/engine"

module ActionMailroom
  extend ActiveSupport::Autoload

  autoload :Mailbox
  autoload :Router
end
