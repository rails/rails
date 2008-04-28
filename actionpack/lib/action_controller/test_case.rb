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
    # When the request.remote_addr remains the default for testing, which is 0.0.0.0, the exception is simply raised inline
    # (bystepping the regular exception handling from rescue_action). If the request.remote_addr is anything else, the regular
    # rescue_action process takes place. This means you can test your rescue_action code by setting remote_addr to something else
    # than 0.0.0.0.
    #
    # The exception is stored in the exception accessor for further inspection.
    module RaiseActionExceptions
      attr_accessor :exception

      def rescue_action(e)
        self.exception = e
        
        if request.remote_addr == "0.0.0.0"
          raise(e)
        else
          super(e)
        end
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
    
    # Cause the action to be rescued according to the regular rules for rescue_action when the visitor is not local
    def rescue_action_in_public!
      @request.remote_addr = '208.77.188.166' # example.com
    end
 end
end