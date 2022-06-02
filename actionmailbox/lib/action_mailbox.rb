# frozen_string_literal: true

require "action_mailbox/mail_ext"

module ActionMailbox
  extend ActiveSupport::Autoload

  autoload :Base
  autoload :Router
  autoload :TestCase

  mattr_accessor :ingress
  mattr_accessor :logger
  mattr_accessor :incinerate, default: true
  mattr_accessor :incinerate_after, default: 30.days
  mattr_accessor :queues, default: {}
  mattr_accessor :storage_service
end
