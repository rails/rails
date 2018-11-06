require "action_mailbox/engine"
require "action_mailbox/mail_ext"

module ActionMailbox
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Router

  mattr_accessor :ingress
  mattr_accessor :logger
  mattr_accessor :incinerate_after, default: 30.days
end
