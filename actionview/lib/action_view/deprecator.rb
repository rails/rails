# frozen_string_literal: true

# :markup: markdown
module ActionView
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
