require 'active_support/test_case'

module ActionController
  class NonInferrableControllerError < ActionControllerError
    def initialize(name)
      super "Unable to determine the controller to test from #{name}. " +
        "You'll need to specify it using 'tests YourController' in your " +
        "test case definition"
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

    def setup
      @controller = self.class.controller_class.new
      @request    = TestRequest.new
      @response   = TestResponse.new
    end
  end
end