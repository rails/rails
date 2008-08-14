require 'strscan'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Custom string iterators
      module Iterators
        def self.append_features(base)
          super unless '1.9'.respond_to?(:each_char)
        end

        # Yields a single-character string for each character in the string.
        # When $KCODE = 'UTF8', multi-byte characters are yielded appropriately.
        def each_char
          scanner, char = StringScanner.new(self), /./mu
          while c = scanner.scan(char)
            yield c
          end
        end
      end
    end
  end
end
