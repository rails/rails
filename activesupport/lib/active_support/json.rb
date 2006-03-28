require 'active_support/json/encoders'

module ActiveSupport
  module JSON #:nodoc:
    class CircularReferenceError < StandardError #:nodoc:
    end
    # returns the literal string as its JSON encoded form.  Useful for passing javascript variables into functions.
    #
    # page.call 'Element.show', ActiveSupport::JSON::Variable.new("$$(#items li)")
    class Variable < String #:nodoc:
      def to_json
        self
      end
    end

    class << self
      REFERENCE_STACK_VARIABLE = :json_reference_stack
      
      def encode(value)
        raise_on_circular_reference(value) do
          Encoders[value.class].call(value)
        end
      end
      
      protected
        def raise_on_circular_reference(value)
          stack = Thread.current[REFERENCE_STACK_VARIABLE] ||= []
          raise CircularReferenceError, 'object references itself' if
            stack.include? value
          stack << value
          yield
        ensure
          stack.pop
        end
    end
  end
end
