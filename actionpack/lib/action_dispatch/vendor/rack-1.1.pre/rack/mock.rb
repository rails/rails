require 'uri'
require 'stringio'
require 'rack/lint'
require 'rack/utils'
require 'rack/response'

module Rack
  # Rack::MockRequest helps testing your Rack application without
  # actually using HTTP.
  #
  # After performing a request on a URL with get/post/put/delete, it
  # returns a MockResponse with useful helper methods for effective
  # testing.
  #
  # You can pass a hash with additional configuration to the
  # get/post/put/delete.
  # <tt>:input</tt>:: A String or IO-like to be used as rack.input.
  # <tt>:fatal</tt>:: Raise a FatalWarning if the app writes to rack.errors.
  # <tt>:lint</tt>:: If true, wrap the application in a Rack::Lint.

  class MockRequest
    class FatalWarning < RuntimeError
    end

    class FatalWarner
      def puts(warning)
        raise FatalWarning, warning
      end

      def write(warning)
        raise FatalWarning, warning
      end

      def flush
      end

      def string
        ""
      end
    end

    DEFAULT_ENV = {
      "rack.version" => [1,0],
      "rack.input" => StringIO.new,
      "rack.errors" => StringIO.new,
      "rack.multithread" => true,
      "rack.multiprocess" => true,
      "rack.run_once" => false,
    }

    def initialize(app)
      @app = app
    end

    def get(uri, opts={})    request("GET", uri, opts)    end
    def post(uri, opts={})   request("POST", uri, opts)   end
    def put(uri, opts={})    request("PUT", uri, opts)    end
    def delete(uri, opts={}) request("DELETE", uri, opts) end

    def request(method="GET", uri="", opts={})
      env = self.class.env_for(uri, opts.merge(:method => method))

      if opts[:lint]
        app = Rack::Lint.new(@app)
      else
        app = @app
      end

      errors = env["rack.errors"]
      MockResponse.new(*(app.call(env) + [errors]))
    end

    # Return the Rack environment used for a request to +uri+.
    def self.env_for(uri="", opts={})
      uri = URI(uri)
      uri.path = "/#{uri.path}" unless uri.path[0] == ?/

      env = DEFAULT_ENV.dup

      env["REQUEST_METHOD"] = opts[:method] ? opts[:method].to_s.upcase : "GET"
      env["SERVER_NAME"] = uri.host || "example.org"
      env["SERVER_PORT"] = uri.port ? uri.port.to_s : "80"
      env["QUERY_STRING"] = uri.query.to_s
      env["PATH_INFO"] = (!uri.path || uri.path.empty?) ? "/" : uri.path
      env["rack.url_scheme"] = uri.scheme || "http"
      env["HTTPS"] = env["rack.url_scheme"] == "https" ? "on" : "off"

      env["SCRIPT_NAME"] = opts[:script_name] || ""

      if opts[:fatal]
        env["rack.errors"] = FatalWarner.new
      else
        env["rack.errors"] = StringIO.new
      end

      if params = opts[:params]
        if env["REQUEST_METHOD"] == "GET"
          params = Utils.parse_nested_query(params) if params.is_a?(String)
          params.update(Utils.parse_nested_query(env["QUERY_STRING"]))
          env["QUERY_STRING"] = Utils.build_nested_query(params)
        elsif !opts.has_key?(:input)
          opts["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
          if params.is_a?(Hash)
            if data = Utils::Multipart.build_multipart(params)
              opts[:input] = data
              opts["CONTENT_LENGTH"] ||= data.length.to_s
              opts["CONTENT_TYPE"] = "multipart/form-data; boundary=#{Utils::Multipart::MULTIPART_BOUNDARY}"
            else
              opts[:input] = Utils.build_nested_query(params)
            end
          else
            opts[:input] = params
          end
        end
      end

      opts[:input] ||= ""
      if String === opts[:input]
        env["rack.input"] = StringIO.new(opts[:input])
      else
        env["rack.input"] = opts[:input]
      end

      env["CONTENT_LENGTH"] ||= env["rack.input"].length.to_s

      opts.each { |field, value|
        env[field] = value  if String === field
      }

      env
    end
  end

  # Rack::MockResponse provides useful helpers for testing your apps.
  # Usually, you don't create the MockResponse on your own, but use
  # MockRequest.

  class MockResponse
    def initialize(status, headers, body, errors=StringIO.new(""))
      @status = status.to_i

      @original_headers = headers
      @headers = Rack::Utils::HeaderHash.new
      headers.each { |field, values|
        @headers[field] = values
        @headers[field] = ""  if values.empty?
      }

      @body = ""
      body.each { |part| @body << part }

      @errors = errors.string if errors.respond_to?(:string)
    end

    # Status
    attr_reader :status

    # Headers
    attr_reader :headers, :original_headers

    def [](field)
      headers[field]
    end


    # Body
    attr_reader :body

    def =~(other)
      @body =~ other
    end

    def match(other)
      @body.match other
    end


    # Errors
    attr_accessor :errors


    include Response::Helpers
  end
end
