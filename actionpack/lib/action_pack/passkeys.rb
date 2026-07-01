# frozen_string_literal: true

module ActionPack
  module Passkeys # :nodoc:
    extend ActiveSupport::Autoload

    mattr_accessor :parent_class_name, default: "ApplicationRecord"
    mattr_accessor :default_registration_options, default: {}
    mattr_accessor :default_authentication_options, default: {}
    mattr_accessor :challenge_url
    mattr_accessor :related_origins, default: []

    autoload :Engine
    autoload :FormHelper
    autoload :Holder
    autoload :Request
  end
end
