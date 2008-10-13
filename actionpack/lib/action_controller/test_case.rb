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

  # Superclass for ActionController functional tests. Functional tests allow you to
  # test a single controller action per test method. This should not be confused with
  # integration tests (see ActionController::IntegrationTest), which are more like
  # "stories" that can involve multiple controllers and mutliple actions (i.e. multiple
  # different HTTP requests).
  #
  # == Basic example
  #
  # Functional tests are written as follows:
  # 1. First, one uses the +get+, +post+, +put+, +delete+ or +head+ method to simulate
  #    an HTTP request.
  # 2. Then, one asserts whether the current state is as expected. "State" can be anything:
  #    the controller's HTTP response, the database contents, etc.
  #
  # For example:
  #
  #   class BooksControllerTest < ActionController::TestCase
  #     def test_create
  #       # Simulate a POST response with the given HTTP parameters.
  #       post(:create, :book => { :title => "Love Hina" })
  #
  #       # Assert that the controller tried to redirect us to
  #       # the created book's URI.
  #       assert_response :found
  #
  #       # Assert that the controller really put the book in the database.
  #       assert_not_nil Book.find_by_title("Love Hina")
  #     end
  #   end
  #
  # == Special instance variables
  #
  # ActionController::TestCase will also automatically provide the following instance
  # variables for use in the tests:
  #
  # <b>@controller</b>::
  #      The controller instance that will be tested.
  # <b>@request</b>::
  #      An ActionController::TestRequest, representing the current HTTP
  #      request. You can modify this object before sending the HTTP request. For example,
  #      you might want to set some session properties before sending a GET request.
  # <b>@response</b>::
  #      An ActionController::TestResponse object, representing the response
  #      of the last HTTP response. In the above example, <tt>@response</tt> becomes valid
  #      after calling +post+. If the various assert methods are not sufficient, then you
  #      may use this object to inspect the HTTP response in detail.
  #
  # (Earlier versions of Rails required each functional test to subclass
  # Test::Unit::TestCase and define @controller, @request, @response in +setup+.)
  #
  # == Controller is automatically inferred
  #
  # ActionController::TestCase will automatically infer the controller under test
  # from the test class name. If the controller cannot be inferred from the test
  # class name, you can explicity set it with +tests+.
  #
  #   class SpecialEdgeCaseWidgetsControllerTest < ActionController::TestCase
  #     tests WidgetController
  #   end
  class TestCase < ActiveSupport::TestCase
    # When the request.remote_addr remains the default for testing, which is 0.0.0.0, the exception is simply raised inline
    # (bystepping the regular exception handling from rescue_action). If the request.remote_addr is anything else, the regular
    # rescue_action process takes place. This means you can test your rescue_action code by setting remote_addr to something else
    # than 0.0.0.0.
    #
    # The exception is stored in the exception accessor for further inspection.
    module RaiseActionExceptions
      attr_accessor :exception

      def rescue_action_without_handler(e)
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
      # Sets the controller class name. Useful if the name can't be inferred from test class.
      # Expects +controller_class+ as a constant. Example: <tt>tests WidgetController</tt>.
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

      @controller.params = {}
      @controller.send(:initialize_current_url)
    end
    
    # Cause the action to be rescued according to the regular rules for rescue_action when the visitor is not local
    def rescue_action_in_public!
      @request.remote_addr = '208.77.188.166' # example.com
    end
 end
end
