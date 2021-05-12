# frozen_string_literal: true

require "uri"

module URI
  class << self
    def parser
      ActiveSupport::Deprecation.warn(<<-MSG.squish)
        URI.parser is deprecated and will be removed in Rails 7.0.
        Use `URI::DEFAULT_PARSER` instead.
      MSG
      URI::DEFAULT_PARSER
    end
  end
end
