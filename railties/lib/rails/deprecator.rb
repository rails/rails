# frozen_string_literal: true

# :markup: markdown
module Rails
  def self.deprecator # :nodoc:
    @deprecator ||= ActiveSupport::Deprecation.new
  end
end
