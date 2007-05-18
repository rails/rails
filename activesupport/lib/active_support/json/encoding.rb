require 'active_support/json/variable'

require 'active_support/json/encoders/object' # Require explicitly for rdoc.
Dir["#{File.dirname(__FILE__)}/encoders/**/*.rb"].each do |file|
  basename = File.basename(file, '.rb')
  unless basename == 'object'
    require "active_support/json/encoders/#{basename}"
  end
end

module ActiveSupport
  module JSON
    # When +true+, Hash#to_json will omit quoting string or symbol keys
    # if the keys are valid JavaScript identifiers.  Note that this is
    # technically improper JSON (all object keys must be quoted), so if
    # you need strict JSON compliance, set this option to +false+.
    mattr_accessor :unquote_hash_key_identifiers
    @@unquote_hash_key_identifiers = true

    class CircularReferenceError < StandardError
    end

    class << self
      REFERENCE_STACK_VARIABLE = :json_reference_stack #:nodoc:

      # Converts a Ruby object into a JSON string.
      def encode(value)
        raise_on_circular_reference(value) do
          value.send(:to_json)
        end
      end

      def can_unquote_identifier?(key) #:nodoc:
        unquote_hash_key_identifiers && 
          ActiveSupport::JSON.valid_identifier?(key)
      end

      protected
        def raise_on_circular_reference(value) #:nodoc:
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
