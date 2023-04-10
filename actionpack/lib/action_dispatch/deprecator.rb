# frozen_string_literal: true

module ActionDispatch
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
