module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      # Enables to conversion of Arrays to human readable lists. ['one', 'two', 'three'] => "one, two, and three"
      module Conversions
        # Converts the array to comma-seperated sentence where the last element is joined by the connector word (default is 'and').
        def to_sentence(connector = 'and')
          if length > 1
            "#{self[0...-1].join(', ')}, #{connector} #{self[-1]}"
          elsif length == 1
            self[0]
          end
        end

        # When an array is given to url_for, it is converted to a slash separated string.
        def to_param
          join '/'
        end
      end
    end
  end
end
