require 'dispatcher'
require 'stringio'
require 'uri'
require 'action_controller/test_process'

module ActionController
  module Integration #:nodoc:
    # An integration Session instance represents a set of requests and responses
    # performed sequentially by some virtual user. Becase you can instantiate
    # multiple sessions and run them side-by-side, you can also mimic (to some
    # limited extent) multiple simultaneous users interacting with your system.
    #
    # Typically, you will instantiate a new session using IntegrationTest#open_session,
    # rather than instantiating Integration::Session directly.
    class Session
      include Test::Unit::Assertions
      include ActionController::Assertions
      include ActionController::TestProcess

      # The integer HTTP status code of the last request.
      attr_reader :status

      # The status message that accompanied the status code of the last request.
      attr_reader :status_message

      # The URI of the last request.
      attr_reader :path

      # The hostname used in the last request.
      attr_accessor :host

      # The remote_addr used in the last request.
      attr_accessor :remote_addr

      # The Accept header to send.
      attr_accessor :accept

      # A map of the cookies returned by the last response, and which will be
      # sent with the next request.
      attr_reader :cookies

      # A map of the headers returned by the last response.
      attr_reader :headers

      # A reference to the controller instance used by the last request.
      attr_reader :controller

      # A reference to the request instance used by the last request.
      attr_reader :request

      # A reference to the response instance used by the last request.
      attr_reader :response

      # Create an initialize a new Session instance.
      def initialize
        reset!
      end

      # Resets the instance. This can be used to reset the state information
      # in an existing session instance, so it can be used from a clean-slate
      # condition.
      #
      #   session.reset!
      def reset!
        @status = @path = @headers = nil
        @result = @status_message = nil
        @https = false
        @cookies = {}
        @controller = @request = @response = nil
      
        self.host        = "www.example.com"
        self.remote_addr = "127.0.0.1"
        self.accept      = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"

        unless @named_routes_configured
          # install the named routes in this session instance.
          klass = class<<self; self; end
          Routing::Routes.named_routes.install(klass)

          # the helpers are made protected by default--we make them public for
          # easier access during testing and troubleshooting.
          klass.send(:public, *Routing::Routes.named_routes.helpers)
          @named_routes_configured = true
        end
      end

      # Specify whether or not the session should mimic a secure HTTPS request.
      #
      #   session.https!
      #   session.https!(false)
      def https!(flag=true)
        @https = flag        
      end

      # Return +true+ if the session is mimicing a secure HTTPS request.
      #
      #   if session.https?
      #     ...
      #   end
      def https?
        @https
      end

      # Set the host name to use in the next request.
      #
      #   session.host! "www.example.com"
      def host!(name)
        @host = name
      end

      # Follow a single redirect response. If the last response was not a
      # redirect, an exception will be raised. Otherwise, the redirect is
      # performed on the location header.
      def follow_redirect!
        raise "not a redirect! #{@status} #{@status_message}" unless redirect?
        get(interpret_uri(headers["location"].first))
        status
      end

      # Performs a GET request, following any subsequent redirect. Note that
      # the redirects are followed until the response is not a redirect--this
      # means you may run into an infinite loop if your redirect loops back to
      # itself.
      def get_via_redirect(path, args={})
        get path, args
        follow_redirect! while redirect?
        status
      end

      # Performs a POST request, following any subsequent redirect. This is
      # vulnerable to infinite loops, the same as #get_via_redirect.
      def post_via_redirect(path, args={})
        post path, args
        follow_redirect! while redirect?
        status
      end

      # Returns +true+ if the last response was a redirect.
      def redirect?
        status/100 == 3
      end

      # Performs a GET request with the given parameters. The parameters may
      # be +nil+, a Hash, or a string that is appropriately encoded
      # (application/x-www-form-urlencoded or multipart/form-data).  The headers
      # should be a hash.  The keys will automatically be upcased, with the 
      # prefix 'HTTP_' added if needed.
      #
      # You can also perform POST, PUT, DELETE, and HEAD requests with #post, 
      # #put, #delete, and #head.
      def get(path, parameters=nil, headers=nil)
        process :get, path, parameters, headers
      end

      # Performs a POST request with the given parameters. See get() for more details.
      def post(path, parameters=nil, headers=nil)
        process :post, path, parameters, headers
      end

      # Performs a PUT request with the given parameters. See get() for more details.
      def put(path, parameters=nil, headers=nil)
        process :put, path, parameters, headers
      end
      
      # Performs a DELETE request with the given parameters. See get() for more details.
      def delete(path, parameters=nil, headers=nil)
        process :delete, path, parameters, headers
      end
      
      # Performs a HEAD request with the given parameters. See get() for more details.
      def head(path, parameters=nil, headers=nil)
        process :head, path, parameters, headers
      end

      # Performs an XMLHttpRequest request with the given parameters, mimicing
      # the request environment created by the Prototype library. The parameters
      # may be +nil+, a Hash, or a string that is appropriately encoded
      # (application/x-www-form-urlencoded or multipart/form-data).  The headers
      # should be a hash.  The keys will automatically be upcased, with the 
      # prefix 'HTTP_' added if needed.
      def xml_http_request(path, parameters=nil, headers=nil)
        headers = (headers || {}).merge(
          "X-Requested-With" => "XMLHttpRequest",
          "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
        )

        post(path, parameters, headers)
      end

      # Returns the URL for the given options, according to the rules specified
      # in the application's routes.
      def url_for(options)
        controller ? controller.url_for(options) : generic_url_rewriter.rewrite(options)
      end

      private
        class MockCGI < CGI #:nodoc:
          attr_accessor :stdinput, :stdoutput, :env_table

          def initialize(env, input=nil)
            self.env_table = env
            self.stdinput = StringIO.new(input || "")
            self.stdoutput = StringIO.new

            super()
          end
        end

        # Tailors the session based on the given URI, setting the HTTPS value
        # and the hostname.
        def interpret_uri(path)
          location = URI.parse(path)
          https! URI::HTTPS === location if location.scheme
          host! location.host if location.host
          location.query ? "#{location.path}?#{location.query}" : location.path
        end

        # Performs the actual request.
        def process(method, path, parameters=nil, headers=nil)
          data = requestify(parameters)
          path = interpret_uri(path) if path =~ %r{://}
          path = "/#{path}" unless path[0] == ?/
          @path = path
          env = {}

          if method == :get
            env["QUERY_STRING"] = data
            data = nil
          end

          env.update(
            "REQUEST_METHOD" => method.to_s.upcase,
            "REQUEST_URI"    => path,
            "HTTP_HOST"      => host,
            "REMOTE_ADDR"    => remote_addr,
            "SERVER_PORT"    => (https? ? "443" : "80"),
            "CONTENT_TYPE"   => "application/x-www-form-urlencoded",
            "CONTENT_LENGTH" => data ? data.length.to_s : nil,
            "HTTP_COOKIE"    => encode_cookies,
            "HTTPS"          => https? ? "on" : "off",
            "HTTP_ACCEPT"    => accept
          )

          (headers || {}).each do |key, value|
            key = key.to_s.upcase.gsub(/-/, "_")
            key = "HTTP_#{key}" unless env.has_key?(key) || key =~ /^HTTP_/
            env[key] = value
          end

          unless ActionController::Base.respond_to?(:clear_last_instantiation!)
            ActionController::Base.send(:include, ControllerCapture)
          end

          ActionController::Base.clear_last_instantiation!

          cgi = MockCGI.new(env, data)
          Dispatcher.dispatch(cgi, ActionController::CgiRequest::DEFAULT_SESSION_OPTIONS, cgi.stdoutput)
          @result = cgi.stdoutput.string

          @controller = ActionController::Base.last_instantiation
          @request = @controller.request
          @response = @controller.response

          # Decorate the response with the standard behavior of the TestResponse
          # so that things like assert_response can be used in integration
          # tests.
          @response.extend(TestResponseBehavior)

          @html_document = nil

          parse_result
          return status
        end

        # Parses the result of the response and extracts the various values,
        # like cookies, status, headers, etc.
        def parse_result
          headers, result_body = @result.split(/\r\n\r\n/, 2)

          @headers = Hash.new { |h,k| h[k] = [] }
          headers.each_line do |line|
            key, value = line.strip.split(/:\s*/, 2)
            @headers[key.downcase] << value
          end

          (@headers['set-cookie'] || [] ).each do |string|
            name, value = string.match(/^(.*?)=(.*?);/)[1,2]
            @cookies[name] = value
          end

          @status, @status_message = @headers["status"].first.split(/ /)
          @status = @status.to_i
        end

        # Encode the cookies hash in a format suitable for passing to a 
        # request.
        def encode_cookies
          cookies.inject("") do |string, (name, value)|
            string << "#{name}=#{value}; "
          end
        end

        # Get a temporarly URL writer object
        def generic_url_rewriter
          cgi = MockCGI.new('REQUEST_METHOD' => "GET",
                            'QUERY_STRING'   => "",
                            "REQUEST_URI"    => "/",
                            "HTTP_HOST"      => host,
                            "SERVER_PORT"    => https? ? "443" : "80",
                            "HTTPS"          => https? ? "on" : "off")                          
          ActionController::UrlRewriter.new(ActionController::CgiRequest.new(cgi), {})
        end

        def name_with_prefix(prefix, name)
          prefix ? "#{prefix}[#{name}]" : name.to_s
        end

        # Convert the given parameters to a request string. The parameters may
        # be a string, +nil+, or a Hash.
        def requestify(parameters, prefix=nil)
          if Hash === parameters
            return nil if parameters.empty?
            parameters.map { |k,v| requestify(v, name_with_prefix(prefix, k)) }.join("&")
          elsif Array === parameters
            parameters.map { |v| requestify(v, name_with_prefix(prefix, "")) }.join("&")
          elsif prefix.nil?
            parameters
          else
            "#{CGI.escape(prefix)}=#{CGI.escape(parameters.to_s)}"
          end
        end

    end

    # A module used to extend ActionController::Base, so that integration tests
    # can capture the controller used to satisfy a request.
    module ControllerCapture #:nodoc:
      def self.included(base)
        base.extend(ClassMethods)
        base.class_eval do
          class << self
            alias_method_chain :new, :capture
          end
        end
      end

      module ClassMethods #:nodoc:
        mattr_accessor :last_instantiation

        def clear_last_instantiation!
          self.last_instantiation = nil
        end

        def new_with_capture(*args)
          controller = new_without_capture(*args)
          self.last_instantiation ||= controller
          controller
        end
      end
    end
  end

  # An IntegrationTest is one that spans multiple controllers and actions,
  # tying them all together to ensure they work together as expected. It tests
  # more completely than either unit or functional tests do, exercising the
  # entire stack, from the dispatcher to the database.
  #
  # At its simplest, you simply extend IntegrationTest and write your tests
  # using the get/post methods:
  #
  #   require "#{File.dirname(__FILE__)}/test_helper"
  #
  #   class ExampleTest < ActionController::IntegrationTest
  #     fixtures :people
  #
  #     def test_login
  #       # get the login page
  #       get "/login"
  #       assert_equal 200, status
  #
  #       # post the login and follow through to the home page
  #       post "/login", :username => people(:jamis).username,
  #         :password => people(:jamis).password
  #       follow_redirect!
  #       assert_equal 200, status
  #       assert_equal "/home", path
  #     end
  #   end
  #
  # However, you can also have multiple session instances open per test, and
  # even extend those instances with assertions and methods to create a very
  # powerful testing DSL that is specific for your application. You can even
  # reference any named routes you happen to have defined!
  #
  #   require "#{File.dirname(__FILE__)}/test_helper"
  #
  #   class AdvancedTest < ActionController::IntegrationTest
  #     fixtures :people, :rooms
  #
  #     def test_login_and_speak
  #       jamis, david = login(:jamis), login(:david)
  #       room = rooms(:office)
  #
  #       jamis.enter(room)
  #       jamis.speak(room, "anybody home?")
  #
  #       david.enter(room)
  #       david.speak(room, "hello!")
  #     end
  #
  #     private
  #
  #       module CustomAssertions
  #         def enter(room)
  #           # reference a named route, for maximum internal consistency!
  #           get(room_url(:id => room.id))
  #           assert(...)
  #           ...
  #         end
  #
  #         def speak(room, message)
  #           xml_http_request "/say/#{room.id}", :message => message
  #           assert(...)
  #           ...
  #         end
  #       end
  #
  #       def login(who)
  #         open_session do |sess|
  #           sess.extend(CustomAssertions)
  #           who = people(who)
  #           sess.post "/login", :username => who.username,
  #             :password => who.password
  #           assert(...)
  #         end
  #       end
  #   end
  class IntegrationTest < Test::Unit::TestCase
    # Work around a bug in test/unit caused by the default test being named
    # as a symbol (:default_test), which causes regex test filters
    # (like "ruby test.rb -n /foo/") to fail because =~ doesn't work on
    # symbols.
    def initialize(name) #:nodoc:
      super(name.to_s)
    end

    # Work around test/unit's requirement that every subclass of TestCase have
    # at least one test method. Note that this implementation extends to all
    # subclasses, as well, so subclasses of IntegrationTest may also exist
    # without any test methods.
    def run(*args) #:nodoc:
      return if @method_name == "default_test"
      super   
    end

    # Because of how use_instantiated_fixtures and use_transactional_fixtures
    # are defined, we need to treat them as special cases. Otherwise, users
    # would potentially have to set their values for both Test::Unit::TestCase
    # ActionController::IntegrationTest, since by the time the value is set on
    # TestCase, IntegrationTest has already been defined and cannot inherit
    # changes to those variables. So, we make those two attributes copy-on-write.

    class << self
      def use_transactional_fixtures=(flag) #:nodoc:
        @_use_transactional_fixtures = true
        @use_transactional_fixtures = flag
      end

      def use_instantiated_fixtures=(flag) #:nodoc:
        @_use_instantiated_fixtures = true
        @use_instantiated_fixtures = flag
      end

      def use_transactional_fixtures #:nodoc:
        @_use_transactional_fixtures ?
          @use_transactional_fixtures :
          superclass.use_transactional_fixtures
      end

      def use_instantiated_fixtures #:nodoc:
        @_use_instantiated_fixtures ?
          @use_instantiated_fixtures :
          superclass.use_instantiated_fixtures
      end
    end

    # Reset the current session. This is useful for testing multiple sessions
    # in a single test case.
    def reset!
      @integration_session = open_session
    end

    %w(get post cookies assigns xml_http_request).each do |method|
      define_method(method) do |*args|
        reset! unless @integration_session
        returning @integration_session.send(method, *args) do
          copy_session_variables!
        end
      end
    end

    # Open a new session instance. If a block is given, the new session is
    # yielded to the block before being returned.
    #
    #   session = open_session do |sess|
    #     sess.extend(CustomAssertions)
    #   end
    #
    # By default, a single session is automatically created for you, but you
    # can use this method to open multiple sessions that ought to be tested
    # simultaneously.
    def open_session
      session = Integration::Session.new

      # delegate the fixture accessors back to the test instance
      extras = Module.new { attr_accessor :delegate, :test_result }
      self.class.fixture_table_names.each do |table_name|
        name = table_name.tr(".", "_")
        next unless respond_to?(name)
        extras.send(:define_method, name) { |*args| delegate.send(name, *args) }
      end

      # delegate add_assertion to the test case
      extras.send(:define_method, :add_assertion) { test_result.add_assertion }
      session.extend(extras)
      session.delegate = self
      session.test_result = @_result

      yield session if block_given?
      session
    end

    # Copy the instance variables from the current session instance into the
    # test instance.
    def copy_session_variables! #:nodoc:
      return unless @integration_session
      %w(controller response request).each do |var|
        instance_variable_set("@#{var}", @integration_session.send(var))
      end
    end

    # Delegate unhandled messages to the current session instance.
    def method_missing(sym, *args, &block)
      reset! unless @integration_session
      returning @integration_session.send(sym, *args, &block) do
        copy_session_variables!
      end
    end
  end
end
