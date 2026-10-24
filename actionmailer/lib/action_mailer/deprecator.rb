# frozen_string_literal: true

module ActionMailer
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
