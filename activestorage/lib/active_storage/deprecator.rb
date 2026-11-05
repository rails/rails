# frozen_string_literal: true

module ActiveStorage
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
