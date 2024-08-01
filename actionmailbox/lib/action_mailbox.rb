# frozen_string_literal: true

require "active_support"
require "active_support/rails"
require "active_support/core_ext/numeric/time"

require "action_mailbox/version"
require "action_mailbox/deprecator"
require "action_mailbox/mail_ext"

# :markup: markdown
# :include: ../README.md
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
