# frozen_string_literal: true

module Rails
  def self.deprecator # :nodoc:
    ActiveSupport::Deprecation._instance
  end
end
