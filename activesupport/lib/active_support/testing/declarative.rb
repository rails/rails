module ActiveSupport
  module Testing
    module Declarative

      def self.extended(klass) #:nodoc:
        klass.class_eval do

          unless method_defined?(:describe)
            def self.describe(text)
              class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
                def self.name
                  "#{text}"
                end
              RUBY_EVAL
            end
          end

        end
      end

      unless defined?(Spec)
        # test "verify something" do
        #   ...
        # end
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
