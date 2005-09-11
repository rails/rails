module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      # Enables to conversion of Arrays to human readable lists. ['one', 'two', 'three'] => "one, two, and three"
      module Conversions
        # Converts the array to comma-seperated sentence where the last element is joined by the connector word. Options:
        # * <tt>:connector</tt>: The word used to join the last element in arrays with more than two elements (default: "and")
        # * <tt>:skip_last_comma</tt>: Set to true to return "a, b and c" instead of "a, b, and c".
        def to_sentence(options = {})
          options.assert_valid_keys(:connector, :skip_last_comma)
          options.reverse_merge! :connector => 'and', :skip_last_comma => false
          
          case length
            when 1
              self[0]
            when 2
              "#{self[0]} #{options[:connector]} #{self[1]}"
            else
              "#{self[0...-1].join(', ')}#{options[:skip_last_comma] ? '' : ','} #{options[:connector]} #{self[-1]}"
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
