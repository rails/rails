# frozen_string_literal: true

module ActionMailbox
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
