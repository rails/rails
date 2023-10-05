# frozen_string_literal: true

require "active_support/deprecation"

module ActiveSupport
  def self.deprecator # :nodoc:
    ActiveSupport::Deprecation._instance
  end
end
