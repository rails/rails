require 'active_support/test_case'
require 'action_controller/testing/process'

module ActionController
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
  # class name, you can explicitly set it with +tests+.
  #
  #   class SpecialEdgeCaseWidgetsControllerTest < ActionController::TestCase
  #     tests WidgetController
  #   end
  #
  # == Testing controller internals
  #
  # In addition to these specific assertions, you also have easy access to various collections that the regular test/unit assertions
  # can be used against. These collections are:
  #
  # * assigns: Instance variables assigned in the action that are available for the view.
  # * session: Objects being saved in the session.
  # * flash: The flash objects currently in the session.
  # * cookies: Cookies being sent to the user on this request.
  #
  # These collections can be used just like any other hash:
  #
  #   assert_not_nil assigns(:person) # makes sure that a @person instance variable was set
  #   assert_equal "Dave", cookies[:name] # makes sure that a cookie called :name was set as "Dave"
  #   assert flash.empty? # makes sure that there's nothing in the flash
  #
  # For historic reasons, the assigns hash uses string-based keys. So assigns[:person] won't work, but assigns["person"] will. To
  # appease our yearning for symbols, though, an alternative accessor has been devised using a method call instead of index referencing.
  # So assigns(:person) will work just like assigns["person"], but again, assigns[:person] will not work.
  #
  # On top of the collections, you have the complete url that a given action redirected to available in redirect_to_url.
  #
  # For redirects within the same controller, you can even call follow_redirect and the redirect will be followed, triggering another
  # action call which can then be asserted against.
  #
  # == Manipulating the request collections
  #
  # The collections described above link to the response, so you can test if what the actions were expected to do happened. But
  # sometimes you also want to manipulate these collections in the incoming request. This is really only relevant for sessions
  # and cookies, though. For sessions, you just do:
  #
  #   @request.session[:key] = "value"
  #   @request.cookies["key"] = "value"
  #
  # == Testing named routes
  #
  # If you're using named routes, they can be easily tested using the original named routes' methods straight in the test case.
  # Example:
  #
  #  assert_redirected_to page_url(:title => 'foo')
  class TestCase < ActiveSupport::TestCase
    include TestProcess

    include ActionDispatch::Assertions

    # When the request.remote_addr remains the default for testing, which is 0.0.0.0, the exception is simply raised inline
    # (bystepping the regular exception handling from rescue_action). If the request.remote_addr is anything else, the regular
    # rescue_action process takes place. This means you can test your rescue_action code by setting remote_addr to something else
    # than 0.0.0.0.
    #
    # The exception is stored in the exception accessor for further inspection.
    module RaiseActionExceptions
      def self.included(base)
        base.class_eval do
          attr_accessor :exception
          protected :exception, :exception=
        end
      end

      protected
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
        prepare_controller_class(new_class) if new_class
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
        nil
      end

      def prepare_controller_class(new_class)
        new_class.send :include, RaiseActionExceptions
      end
    end

    def setup_controller_request_and_response
      @request = TestRequest.new
      @response = TestResponse.new

      if klass = self.class.controller_class
        @controller ||= klass.new rescue nil
      end

      if @controller
        @controller.request = @request
        @controller.params = {}
        @controller.send(:initialize_current_url)
      end
    end

    # Cause the action to be rescued according to the regular rules for rescue_action when the visitor is not local
    def rescue_action_in_public!
      @request.remote_addr = '208.77.188.166' # example.com
    end
  end
end
