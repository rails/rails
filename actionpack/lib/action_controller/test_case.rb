require 'active_support/test_case'

module ActionController
  class NonInferrableControllerError < ActionControllerError
    def initialize(name)
      @name = name
      super "Unable to determine the controller to test from #{name}. " +
        "You'll need to specify it using 'tests YourController' in your " +
        "test case definition. This could mean that #{inferred_controller_name} does not exist " +
        "or it contains syntax errors"
    end

    def inferred_controller_name
      @name.sub(/Test$/, '')
    end
  end

  class TestCase < ActiveSupport::TestCase
    @@controller_class = nil
    class << self
      def tests(controller_class)
        self.controller_class = controller_class
      end

      def controller_class=(new_class)
        prepare_controller_class(new_class)
        write_inheritable_attribute(:controller_class, new_class)
      end

      def controller_class
        if current_controller_class = read_inheritable_attribute(:controller_class)
          current_controller_class
        else
          self.controller_class= determine_default_controller_class(name)
        end
      end

      def determine_default_controller_class(name)
        name.sub(/Test$/, '').constantize
      rescue NameError
        raise NonInferrableControllerError.new(name)
      end

      def prepare_controller_class(new_class)
        new_class.class_eval do
          def rescue_action(e)
            raise e
          end
        end
      end
    end

    def setup_with_controller
      @controller = self.class.controller_class.new
      @request    = TestRequest.new
      @response   = TestResponse.new
    end
    alias_method :setup, :setup_with_controller

    def self.method_added(method)
      if method.to_s == 'setup'
        unless method_defined?(:setup_without_controller)
          alias_method :setup_without_controller, :setup
          define_method(:setup) do
            setup_with_controller
            setup_without_controller
          end
        end
      end
    end
 end
end
