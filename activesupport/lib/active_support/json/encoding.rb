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
