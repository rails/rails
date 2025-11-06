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
          test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
          test_with_name(test_name, each: each, &block)
        end

        private
          def test_with_name(test_name, each: [], &block)
            if each.any?
              each.each do |value|
                parameterized_test_name = "#{test_name} |#{value.inspect}|".to_sym
                test_with_name(parameterized_test_name) { instance_exec(value, &block) }
              end
            else
              defined = method_defined? test_name
              raise "#{test_name} is already defined in #{self}" if defined
              if block_given?
                define_method(test_name, &block)
              else
                define_method(test_name) do
                  flunk "No implementation provided for #{test_name}"
                end
              end
            end
          end
      end
    end
  end
end
