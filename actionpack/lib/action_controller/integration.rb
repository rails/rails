require 'active_support/test_case'
require 'action_controller/dispatcher'
require 'action_controller/test_process'

require 'stringio'
require 'uri'

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

      # A running counter of the number of requests processed.
      attr_accessor :request_count

      class MultiPartNeededException < Exception
      end

      # Create and initialize a new Session instance.
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
        @request_count = 0

        self.host        = "www.example.com"
        self.remote_addr = "127.0.0.1"
        self.accept      = "text/xml,application/xml,application/xhtml+xml,text/html;q=0.9,text/plain;q=0.8,image/png,*/*;q=0.5"

        unless defined? @named_routes_configured
          # install the named routes in this session instance.
          klass = class<<self; self; end
          Routing::Routes.install_helpers(klass)

          # the helpers are made protected by default--we make them public for
          # easier access during testing and troubleshooting.
          klass.module_eval { public *Routing::Routes.named_routes.helpers }
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

      # Return +true+ if the session is mimicking a secure HTTPS request.
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
        get(interpret_uri(headers['location'].first))
        status
      end

      # Performs a request using the specified method, following any subsequent
      # redirect. Note that the redirects are followed until the response is
      # not a redirect--this means you may run into an infinite loop if your
      # redirect loops back to itself.
      def request_via_redirect(http_method, path, parameters = nil, headers = nil)
        send(http_method, path, parameters, headers)
        follow_redirect! while redirect?
        status
      end

      # Performs a GET request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def get_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:get, path, parameters, headers)
      end

      # Performs a POST request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def post_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:post, path, parameters, headers)
      end

      # Performs a PUT request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def put_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:put, path, parameters, headers)
      end

      # Performs a DELETE request, following any subsequent redirect.
      # See +request_via_redirect+ for more information.
      def delete_via_redirect(path, parameters = nil, headers = nil)
        request_via_redirect(:delete, path, parameters, headers)
      end

      # Returns +true+ if the last response was a redirect.
      def redirect?
        status/100 == 3
      end

      # Performs a GET request with the given parameters.
      #
      # - +path+: The URI (as a String) on which you want to perform a GET request.
      # - +parameters+: The HTTP parameters that you want to pass. This may be +nil+,
      #   a Hash, or a String that is appropriately encoded
      #   (<tt>application/x-www-form-urlencoded</tt> or <tt>multipart/form-data</tt>).
      # - +headers+: Additional HTTP headers to pass, as a Hash. The keys will
      #   automatically be upcased, with the prefix 'HTTP_' added if needed.
      #
      # This method returns an AbstractResponse object, which one can use to inspect
      # the details of the response. Furthermore, if this method was called from an
      # ActionController::IntegrationTest object, then that object's <tt>@response</tt>
      # instance variable will point to the same response object.
      #
      # You can also perform POST, PUT, DELETE, and HEAD requests with +post+,
      # +put+, +delete+, and +head+.
      def get(path, parameters = nil, headers = nil)
        process :get, path, parameters, headers
      end

      # Performs a POST request with the given parameters. See get() for more details.
      def post(path, parameters = nil, headers = nil)
        process :post, path, parameters, headers
      end

      # Performs a PUT request with the given parameters. See get() for more details.
      def put(path, parameters = nil, headers = nil)
        process :put, path, parameters, headers
      end

      # Performs a DELETE request with the given parameters. See get() for more details.
      def delete(path, parameters = nil, headers = nil)
        process :delete, path, parameters, headers
      end

      # Performs a HEAD request with the given parameters. See get() for more details.
      def head(path, parameters = nil, headers = nil)
        process :head, path, parameters, headers
      end

      # Performs an XMLHttpRequest request with the given parameters, mirroring
      # a request from the Prototype library.
      #
      # The request_method is :get, :post, :put, :delete or :head; the
      # parameters are +nil+, a hash, or a url-encoded or multipart string;
      # the headers are a hash.  Keys are automatically upcased and prefixed
      # with 'HTTP_' if not already.
      def xml_http_request(request_method, path, parameters = nil, headers = nil)
        headers ||= {}
        headers['X-Requested-With'] = 'XMLHttpRequest'
        headers['Accept'] ||= 'text/javascript, text/html, application/xml, text/xml, */*'

        process(request_method, path, parameters, headers)
      end
      alias xhr :xml_http_request

      # Returns the URL for the given options, according to the rules specified
      # in the application's routes.
      def url_for(options)
        controller ? controller.url_for(options) : generic_url_rewriter.rewrite(options)
      end

      private
        # Tailors the session based on the given URI, setting the HTTPS value
        # and the hostname.
        def interpret_uri(path)
          location = URI.parse(path)
          https! URI::HTTPS === location if location.scheme
          host! location.host if location.host
          location.query ? "#{location.path}?#{location.query}" : location.path
        end

        # Performs the actual request.
        def process(method, path, parameters = nil, headers = nil)
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
            ActionController::Base.module_eval { include ControllerCapture }
          end

          ActionController::Base.clear_last_instantiation!

          env['rack.input'] = data.is_a?(IO) ? data : StringIO.new(data || '')
          @status, @headers, result_body = ActionController::Dispatcher.new.mark_as_test_request!.call(env)
          @request_count += 1

          @controller = ActionController::Base.last_instantiation
          @request = @controller.request
          @response = @controller.response

          # Decorate the response with the standard behavior of the TestResponse
          # so that things like assert_response can be used in integration
          # tests.
          @response.extend(TestResponseBehavior)

          @html_document = nil

          # Inject status back in for backwords compatibility with CGI
          @headers['Status'] = @status

          @status, @status_message = @status.split(/ /)
          @status = @status.to_i

          cgi_headers = Hash.new { |h,k| h[k] = [] }
          @headers.each do |key, value|
            cgi_headers[key.downcase] << value
          end
          cgi_headers['set-cookie'] = cgi_headers['set-cookie'].first
          @headers = cgi_headers

          @response.headers['cookie'] ||= []
          (@headers['set-cookie'] || []).each do |cookie|
            name, value = cookie.match(/^([^=]*)=([^;]*);/)[1,2]
            @cookies[name] = value

            # Fake CGI cookie header
            # DEPRECATE: Use response.headers["Set-Cookie"] instead
            @response.headers['cookie'] << CGI::Cookie::new("name" => name, "value" => value)
          end

          return status
        rescue MultiPartNeededException
          boundary = "----------XnJLe9ZIbbGUYtzPQJ16u1"
          status = process(method, path, multipart_body(parameters, boundary), (headers || {}).merge({"CONTENT_TYPE" => "multipart/form-data; boundary=#{boundary}"}))
          return status
        end

        # Encode the cookies hash in a format suitable for passing to a
        # request.
        def encode_cookies
          cookies.inject("") do |string, (name, value)|
            string << "#{name}=#{value}; "
          end
        end

        # Get a temporary URL writer object
        def generic_url_rewriter
          env = {
            'REQUEST_METHOD' => "GET",
            'QUERY_STRING'   => "",
            "REQUEST_URI"    => "/",
            "HTTP_HOST"      => host,
            "SERVER_PORT"    => https? ? "443" : "80",
            "HTTPS"          => https? ? "on" : "off"
          }
          ActionController::UrlRewriter.new(ActionController::RackRequest.new(env), {})
        end

        def name_with_prefix(prefix, name)
          prefix ? "#{prefix}[#{name}]" : name.to_s
        end

        # Convert the given parameters to a request string. The parameters may
        # be a string, +nil+, or a Hash.
        def requestify(parameters, prefix=nil)
          if TestUploadedFile === parameters
            raise MultiPartNeededException
          elsif Hash === parameters
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

        def multipart_requestify(params, first=true)
          returning Hash.new do |p|
            params.each do |key, value|
              k = first ? CGI.escape(key.to_s) : "[#{CGI.escape(key.to_s)}]"
              if Hash === value
                multipart_requestify(value, false).each do |subkey, subvalue|
                  p[k + subkey] = subvalue
                end
              else
                p[k] = value
              end
            end
          end
        end

        def multipart_body(params, boundary)
          multipart_requestify(params).map do |key, value|
            if value.respond_to?(:original_filename)
              File.open(value.path) do |f|
                f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)

                <<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"; filename="#{CGI.escape(value.original_filename)}"\r
Content-Type: #{value.content_type}\r
Content-Length: #{File.stat(value.path).size}\r
\r
#{f.read}\r
EOF
              end
            else
<<-EOF
--#{boundary}\r
Content-Disposition: form-data; name="#{key}"\r
\r
#{value}\r
EOF
            end
          end.join("")+"--#{boundary}--\r"
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

    module Runner
      # Reset the current session. This is useful for testing multiple sessions
      # in a single test case.
      def reset!
        @integration_session = open_session
      end

      %w(get post put head delete cookies assigns
         xml_http_request xhr get_via_redirect post_via_redirect).each do |method|
        define_method(method) do |*args|
          reset! unless @integration_session
          # reset the html_document variable, but only for new get/post calls
          @html_document = nil unless %w(cookies assigns).include?(method)
          returning @integration_session.__send__(method, *args) do
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
        if self.class.respond_to?(:fixture_table_names)
          self.class.fixture_table_names.each do |table_name|
            name = table_name.tr(".", "_")
            next unless respond_to?(name)
            extras.__send__(:define_method, name) { |*args| delegate.send(name, *args) }
          end
        end

        # delegate add_assertion to the test case
        extras.__send__(:define_method, :add_assertion) { test_result.add_assertion }
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
          instance_variable_set("@#{var}", @integration_session.__send__(var))
        end
      end

      # Delegate unhandled messages to the current session instance.
      def method_missing(sym, *args, &block)
        reset! unless @integration_session
        returning @integration_session.__send__(sym, *args, &block) do
          copy_session_variables!
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
  class IntegrationTest < ActiveSupport::TestCase
    include Integration::Runner

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
  end
end
