# frozen_string_literal: true

module ActiveSupport
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
