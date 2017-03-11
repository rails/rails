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
        def test(name, &block)
          prefix = ("#{@__context__} " if defined? @__context__).to_s
          test_name = "test_#{(prefix + name).gsub(/\s+/, '_')}".to_sym
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

        # Helper to group related tests together.
        #
        #   describe "attributes not backed by database columns" do
        #     test "not dirty when unchanged" do
        #     test "always initialized"
        #     test "return the default on models loaded from database"
        #   end
        #
        # Multiple descriptions cannot be nested.
        def describe(context)
          raise "#{@__context__} already defined" if defined? @__context__
          @__context__ = context.to_s
          begin
            yield
          ensure
            remove_instance_variable(:@__context__)
          end
        end
      end
    end
  end
end
