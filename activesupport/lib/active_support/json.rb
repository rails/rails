require 'active_support/json/encoders'

module ActiveSupport
  module JSON #:nodoc:
    class CircularReferenceError < StandardError #:nodoc:
    end
    
    # A string that returns itself as as its JSON-encoded form.
    class Variable < String #:nodoc:
      def to_json
        self
      end
    end
    
    # When +true+, Hash#to_json will omit quoting string or symbol keys
    # if the keys are valid JavaScript identifiers.  Note that this is
    # technically improper JSON (all object keys must be quoted), so if
    # you need strict JSON compliance, set this option to +false+.
    mattr_accessor :unquote_hash_key_identifiers
    @@unquote_hash_key_identifiers = true

    class << self
      REFERENCE_STACK_VARIABLE = :json_reference_stack
      
      def encode(value)
        raise_on_circular_reference(value) do
          Encoders[value.class].call(value)
        end
      end
      
      def can_unquote_identifier?(key)
        return false unless unquote_hash_key_identifiers
        key.to_s =~ /^[[:alpha:]_$][[:alnum:]_$]*$/
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
