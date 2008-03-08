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
    module RaiseActionExceptions
      def rescue_action(e)
        raise e
      end
    end

    setup :setup_controller_request_and_response

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
          self.controller_class = determine_default_controller_class(name)
        end
      end

      def determine_default_controller_class(name)
        name.sub(/Test$/, '').constantize
      rescue NameError
        raise NonInferrableControllerError.new(name)
      end

      def prepare_controller_class(new_class)
        new_class.send :include, RaiseActionExceptions
      end
    end

    def setup_controller_request_and_response
      @controller = self.class.controller_class.new
      @controller.request = @request = TestRequest.new
      @response = TestResponse.new
    end
 end
end
