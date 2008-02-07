module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Base64 #:nodoc:
      module Encoding
        # Encodes the value as base64 without the newline breaks. This makes the base64 encoding readily usable as URL parameters 
        # or memcache keys without further processing.
        def encode64s(value)
          encode64(value).gsub(/\n/, '')
        end
      end
    end
  end
end
