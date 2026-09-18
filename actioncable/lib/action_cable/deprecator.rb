# frozen_string_literal: true

# :markup: markdown

module ActionCable
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
