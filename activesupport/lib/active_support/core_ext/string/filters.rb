module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      module Filters
        # Returns the string, first removing all whitespace on both ends of
        # the string, and then changing remaining consecutive whitespace
        # groups into one space each.
        #
        # Examples:
        #   %{ Multi-line
        #      string }.squish                   # => "Multi-line string"
        #   " foo   bar    \n   \t   boo".squish # => "foo bar boo"
        def squish
          dup.squish!
        end

        # Performs a destructive squish. See String#squish.
        def squish!
          strip!
          gsub!(/\s+/, ' ')
          self
        end
      end
    end
  end
end
