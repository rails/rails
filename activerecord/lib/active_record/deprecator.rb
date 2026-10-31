# frozen_string_literal: true

module ActiveRecord
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
