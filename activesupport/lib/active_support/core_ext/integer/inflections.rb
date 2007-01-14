require 'active_support/inflector'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Integer #:nodoc:
      module Inflections
        # Ordinalize turns a number into an ordinal string used to denote the
        # position in an ordered sequence such as 1st, 2nd, 3rd, 4th.
        #
        # Examples
        #   1.ordinalize    # => "1st"
        #   2.ordinalize    # => "2nd"
        #   1002.ordinalize # => "1002nd"
        #   1003.ordinalize # => "1003rd"
        def ordinalize
          Inflector.ordinalize(self)
        end
      end
    end
  end
end
