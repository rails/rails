# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module ActionPack
  module Passkeys # :nodoc:
    extend ActiveSupport::Autoload

    mattr_accessor :parent_class_name, default: "ApplicationRecord"
    mattr_accessor :default_registration_options, default: {}
    mattr_accessor :default_authentication_options, default: {}
    mattr_accessor :registration_challenge_expiration, default: 10.minutes
    mattr_accessor :authentication_challenge_expiration, default: 5.minutes
    mattr_accessor :challenge_url
    mattr_accessor :related_origins, default: []

    autoload :Engine
    autoload :FormHelper
    autoload :Holder
    autoload :Request
  end
end
