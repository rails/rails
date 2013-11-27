module ActiveSupport
  module Testing
    module Declarative

      def self.extended(klass) #:nodoc:
        klass.class_eval do

          unless method_defined?(:describe)
            def self.describe(text)
              if block_given?
                super
              else
                message = "`describe` without a block is deprecated, please switch to: `def self.name; #{text.inspect}; end`\n"
                ActiveSupport::Deprecation.warn message

                class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
                  def self.name
                    "#{text}"
                  end
                RUBY_EVAL
              end
            end
          end

        end
      end

      unless defined?(Spec)
        # Helper to define a test method using a String. Under the hood, it replaces
        # spaces with underscores and defines the test method.
        #
        #   test "verify something" do
        #     ...
        #   end
        def test(name, &block)
          test_name = "test_#{name.gsub(/\s+/,'_')}".to_sym
          defined = instance_method(test_name) rescue false
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
