# frozen_string_literal: true

module ActiveSupport
  module Testing
    module Declarative
      unless defined?(Spec)
        # Helper to define a test method using a String. Under the hood, it replaces
        # spaces with underscores and defines the test method.
        #
        #   test "verify something" do
        #     ...
        #   end
        #
        # Also supports parameterized tests.
        #
        #   test "verify something", each: [ ... ] do |value|
        #     ...
        #   end
        def test(name, each: [], &block)
          test_name = "test_#{name.gsub(/\s+/, '_')}"

          if each.any?
            each.each do |value|
              parameterized_test_name = "#{test_name} |#{value.inspect}|"
              define_test_method(parameterized_test_name) { instance_exec(value, &block) }
            end
          else
            define_test_method(test_name, &block)
          end
        end

        private
          def define_test_method(test_name, &block)
            test_name = test_name.to_sym
            defined = method_defined? test_name
            raise "#{test_name} is already defined in #{self}" if defined
            if block_given?
              define_method(test_name, &block)
            else
              define_method(test_name) do
                flunk "No implementation provided for #{name}"
              end
            end
          end
      end
    end
  end
end
