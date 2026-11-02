# frozen_string_literal: true

module ActiveSupport
  def self.deprecator # :nodoc:
    ActiveSupport::Deprecation._instance
  end
end
