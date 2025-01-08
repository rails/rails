# frozen_string_literal: true

module ActiveSupport # :nodoc:
  module Multibyte
    autoload :Chars, "active_support/multibyte/chars"
    autoload :Unicode, "active_support/multibyte/unicode"

    # The proxy class returned when calling mb_chars. You can use this accessor
    # to configure your own proxy class so you can support other encodings. See
    # the ActiveSupport::Multibyte::Chars implementation for an example how to
    # do this.
    #
    #   ActiveSupport::Multibyte.proxy_class = CharsForUTF32
    def self.proxy_class=(klass)
      ActiveSupport.deprecator.warn(
        "ActiveSupport::Multibyte.proxy_class= is deprecated and will be removed in Rails 8.2. " \
        "Use normal string methods instead."
      )
      @proxy_class = klass
    end

    # Returns the current proxy class.
    def self.proxy_class
      @proxy_class ||= ActiveSupport::Multibyte::Chars
    end
  end
end
