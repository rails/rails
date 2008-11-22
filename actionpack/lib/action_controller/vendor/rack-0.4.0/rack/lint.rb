module Rack
  # Rack::Lint validates your application and the requests and
  # responses according to the Rack spec.

  class Lint
    def initialize(app)
      @app = app
    end

    # :stopdoc:

    class LintError < RuntimeError; end
    module Assertion
      def assert(message, &block)
        unless block.call
          raise LintError, message
        end
      end
    end
    include Assertion

    ## This specification aims to formalize the Rack protocol.  You
    ## can (and should) use Rack::Lint to enforce it.
    ##
    ## When you develop middleware, be sure to add a Lint before and
    ## after to catch all mistakes.

    ## = Rack applications

    ## A Rack application is an Ruby object (not a class) that
    ## responds to +call+.
    def call(env=nil) 
      dup._call(env) 
    end

    def _call(env)
      ## It takes exactly one argument, the *environment*
      assert("No env given") { env }
      check_env env

      env['rack.input'] = InputWrapper.new(env['rack.input'])
      env['rack.errors'] = ErrorWrapper.new(env['rack.errors'])

      ## and returns an Array of exactly three values:
      status, headers, @body = @app.call(env)
      ## The *status*,
      check_status status
      ## the *headers*,
      check_headers headers
      ## and the *body*.
      check_content_type status, headers
      [status, headers, self]
    end

    ## == The Environment
    def check_env(env)
      ## The environment must be an true instance of Hash (no
      ## subclassing allowed) that includes CGI-like headers.
      ## The application is free to modify the environment.
      assert("env #{env.inspect} is not a Hash, but #{env.class}") {
        env.instance_of? Hash
      }

      ##
      ## The environment is required to include these variables
      ## (adopted from PEP333), except when they'd be empty, but see
      ## below.

      ## <tt>REQUEST_METHOD</tt>:: The HTTP request method, such as
      ##                           "GET" or "POST". This cannot ever
      ##                           be an empty string, and so is
      ##                           always required.

      ## <tt>SCRIPT_NAME</tt>:: The initial portion of the request
      ##                        URL's "path" that corresponds to the
      ##                        application object, so that the
      ##                        application knows its virtual
      ##                        "location". This may be an empty
      ##                        string, if the application corresponds
      ##                        to the "root" of the server.

      ## <tt>PATH_INFO</tt>:: The remainder of the request URL's
      ##                      "path", designating the virtual
      ##                      "location" of the request's target
      ##                      within the application. This may be an
      ##                      empty string, if the request URL targets
      ##                      the application root and does not have a
      ##                      trailing slash.

      ## <tt>QUERY_STRING</tt>:: The portion of the request URL that
      ##                         follows the <tt>?</tt>, if any. May be
      ##                         empty, but is always required!

      ## <tt>SERVER_NAME</tt>, <tt>SERVER_PORT</tt>:: When combined with <tt>SCRIPT_NAME</tt> and <tt>PATH_INFO</tt>, these variables can be used to complete the URL. Note, however, that <tt>HTTP_HOST</tt>, if present, should be used in preference to <tt>SERVER_NAME</tt> for reconstructing the request URL.  <tt>SERVER_NAME</tt> and <tt>SERVER_PORT</tt> can never be empty strings, and so are always required.

      ## <tt>HTTP_</tt> Variables:: Variables corresponding to the
      ##                            client-supplied HTTP request
      ##                            headers (i.e., variables whose
      ##                            names begin with <tt>HTTP_</tt>). The
      ##                            presence or absence of these
      ##                            variables should correspond with
      ##                            the presence or absence of the
      ##                            appropriate HTTP header in the
      ##                            request.

      ## In addition to this, the Rack environment must include these
      ## Rack-specific variables:

      ## <tt>rack.version</tt>:: The Array [0,1], representing this version of Rack.
      ## <tt>rack.url_scheme</tt>:: +http+ or +https+, depending on the request URL.
      ## <tt>rack.input</tt>:: See below, the input stream.
      ## <tt>rack.errors</tt>:: See below, the error stream.
      ## <tt>rack.multithread</tt>:: true if the application object may be simultaneously invoked by another thread in the same process, false otherwise.
      ## <tt>rack.multiprocess</tt>:: true if an equivalent application object may be simultaneously invoked by another process, false otherwise.
      ## <tt>rack.run_once</tt>:: true if the server expects (but does not guarantee!) that the application will only be invoked this one time during the life of its containing process. Normally, this will only be true for a server based on CGI (or something similar).

      ## The server or the application can store their own data in the
      ## environment, too.  The keys must contain at least one dot,
      ## and should be prefixed uniquely.  The prefix <tt>rack.</tt>
      ## is reserved for use with the Rack core distribution and must
      ## not be used otherwise.
      ##

      %w[REQUEST_METHOD SERVER_NAME SERVER_PORT
         QUERY_STRING
         rack.version rack.input rack.errors
         rack.multithread rack.multiprocess rack.run_once].each { |header|
        assert("env missing required key #{header}") { env.include? header }
      }

      ## The environment must not contain the keys
      ## <tt>HTTP_CONTENT_TYPE</tt> or <tt>HTTP_CONTENT_LENGTH</tt>
      ## (use the versions without <tt>HTTP_</tt>).
      %w[HTTP_CONTENT_TYPE HTTP_CONTENT_LENGTH].each { |header|
        assert("env contains #{header}, must use #{header[5,-1]}") {
          not env.include? header
        }
      }

      ## The CGI keys (named without a period) must have String values.
      env.each { |key, value|
        next  if key.include? "."   # Skip extensions
        assert("env variable #{key} has non-string value #{value.inspect}") {
          value.instance_of? String
        }
      }

      ##
      ## There are the following restrictions:

      ## * <tt>rack.version</tt> must be an array of Integers.
      assert("rack.version must be an Array, was #{env["rack.version"].class}") {
        env["rack.version"].instance_of? Array
      }
      ## * <tt>rack.url_scheme</tt> must either be +http+ or +https+.
      assert("rack.url_scheme unknown: #{env["rack.url_scheme"].inspect}") {
        %w[http https].include? env["rack.url_scheme"]
      }

      ## * There must be a valid input stream in <tt>rack.input</tt>.
      check_input env["rack.input"]
      ## * There must be a valid error stream in <tt>rack.errors</tt>.
      check_error env["rack.errors"]

      ## * The <tt>REQUEST_METHOD</tt> must be one of +GET+, +POST+, +PUT+,
      ##   +DELETE+, +HEAD+, +OPTIONS+, +TRACE+.
      assert("REQUEST_METHOD unknown: #{env["REQUEST_METHOD"]}") {
        %w[GET POST PUT DELETE
           HEAD OPTIONS TRACE].include?(env["REQUEST_METHOD"])
      }

      ## * The <tt>SCRIPT_NAME</tt>, if non-empty, must start with <tt>/</tt>
      assert("SCRIPT_NAME must start with /") {
        !env.include?("SCRIPT_NAME") ||
        env["SCRIPT_NAME"] == "" ||
        env["SCRIPT_NAME"] =~ /\A\//
      }
      ## * The <tt>PATH_INFO</tt>, if non-empty, must start with <tt>/</tt>
      assert("PATH_INFO must start with /") {
        !env.include?("PATH_INFO") ||
        env["PATH_INFO"] == "" ||
        env["PATH_INFO"] =~ /\A\//
      }
      ## * The <tt>CONTENT_LENGTH</tt>, if given, must consist of digits only.
      assert("Invalid CONTENT_LENGTH: #{env["CONTENT_LENGTH"]}") {
        !env.include?("CONTENT_LENGTH") || env["CONTENT_LENGTH"] =~ /\A\d+\z/
      }

      ## * One of <tt>SCRIPT_NAME</tt> or <tt>PATH_INFO</tt> must be
      ##   set.  <tt>PATH_INFO</tt> should be <tt>/</tt> if
      ##   <tt>SCRIPT_NAME</tt> is empty.
      assert("One of SCRIPT_NAME or PATH_INFO must be set (make PATH_INFO '/' if SCRIPT_NAME is empty)") {
        env["SCRIPT_NAME"] || env["PATH_INFO"]
      }
      ##   <tt>SCRIPT_NAME</tt> never should be <tt>/</tt>, but instead be empty.
      assert("SCRIPT_NAME cannot be '/', make it '' and PATH_INFO '/'") {
        env["SCRIPT_NAME"] != "/"
      }
    end

    ## === The Input Stream
    def check_input(input)
      ## The input stream must respond to +gets+, +each+ and +read+.
      [:gets, :each, :read].each { |method|
        assert("rack.input #{input} does not respond to ##{method}") {
          input.respond_to? method
        }
      }
    end

    class InputWrapper
      include Assertion

      def initialize(input)
        @input = input
      end

      ## * +gets+ must be called without arguments and return a string,
      ##   or +nil+ on EOF.
      def gets(*args)
        assert("rack.input#gets called with arguments") { args.size == 0 }
        v = @input.gets
        assert("rack.input#gets didn't return a String") {
          v.nil? or v.instance_of? String
        }
        v
      end

      ## * +read+ must be called without or with one integer argument
      ##   and return a string, or +nil+ on EOF.
      def read(*args)
        assert("rack.input#read called with too many arguments") {
          args.size <= 1
        }
        if args.size == 1
          assert("rack.input#read called with non-integer argument") {
            args.first.kind_of? Integer
          }
        end
        v = @input.read(*args)
        assert("rack.input#read didn't return a String") {
          v.nil? or v.instance_of? String
        }
        v
      end

      ## * +each+ must be called without arguments and only yield Strings.
      def each(*args)
        assert("rack.input#each called with arguments") { args.size == 0 }
        @input.each { |line|
          assert("rack.input#each didn't yield a String") {
            line.instance_of? String
          }
          yield line
        }
      end

      ## * +close+ must never be called on the input stream.
      def close(*args)
        assert("rack.input#close must not be called") { false }
      end
    end

    ## === The Error Stream
    def check_error(error)
      ## The error stream must respond to +puts+, +write+ and +flush+.
      [:puts, :write, :flush].each { |method|
        assert("rack.error #{error} does not respond to ##{method}") {
          error.respond_to? method
        }
      }
    end

    class ErrorWrapper
      include Assertion

      def initialize(error)
        @error = error
      end

      ## * +puts+ must be called with a single argument that responds to +to_s+.
      def puts(str)
        @error.puts str
      end

      ## * +write+ must be called with a single argument that is a String.
      def write(str)
        assert("rack.errors#write not called with a String") { str.instance_of? String }
        @error.write str
      end

      ## * +flush+ must be called without arguments and must be called
      ##   in order to make the error appear for sure.
      def flush
        @error.flush
      end

      ## * +close+ must never be called on the error stream.
      def close(*args)
        assert("rack.errors#close must not be called") { false }
      end
    end

    ## == The Response

    ## === The Status
    def check_status(status)
      ## The status, if parsed as integer (+to_i+), must be greater than or equal to 100.
      assert("Status must be >=100 seen as integer") { status.to_i >= 100 }
    end

    ## === The Headers
    def check_headers(header)
      ## The header must respond to each, and yield values of key and value.
      assert("headers object should respond to #each, but doesn't (got #{header.class} as headers)") {
         header.respond_to? :each
      }
      header.each { |key, value|
        ## The header keys must be Strings.
        assert("header key must be a string, was #{key.class}") {
          key.instance_of? String
        }
        ## The header must not contain a +Status+ key,
        assert("header must not contain Status") { key.downcase != "status" }
        ## contain keys with <tt>:</tt> or newlines in their name,
        assert("header names must not contain : or \\n") { key !~ /[:\n]/ }
        ## contain keys names that end in <tt>-</tt> or <tt>_</tt>,
        assert("header names must not end in - or _") { key !~ /[-_]\z/ }
        ## but only contain keys that consist of
        ## letters, digits, <tt>_</tt> or <tt>-</tt> and start with a letter.
        assert("invalid header name: #{key}") { key =~ /\A[a-zA-Z][a-zA-Z0-9_-]*\z/ }
        ##
        ## The values of the header must respond to #each.
        assert("header values must respond to #each, but the value of " +
          "'#{key}' doesn't (is #{value.class})") { value.respond_to? :each }
        value.each { |item|
          ## The values passed on #each must be Strings
          assert("header values must consist of Strings, but '#{key}' also contains a #{item.class}") {
            item.instance_of?(String)
          }
          ## and not contain characters below 037.
          assert("invalid header value #{key}: #{item.inspect}") {
            item !~ /[\000-\037]/
          }
        }
      }
    end

    ## === The Content-Type
    def check_content_type(status, headers)
      headers.each { |key, value|
        ## There must be a <tt>Content-Type</tt>, except when the
        ## +Status+ is 204 or 304, in which case there must be none
        ## given.
        if key.downcase == "content-type"
          assert("Content-Type header found in #{status} response, not allowed"){
            not [204, 304].include? status.to_i
          }
          return
        end
      }
      assert("No Content-Type header found") {
        [204, 304].include? status.to_i
      }
    end

    ## === The Body
    def each
      @closed = false
      ## The Body must respond to #each
      @body.each { |part|
        ## and must only yield String values.
        assert("Body yielded non-string value #{part.inspect}") {
          part.instance_of? String
        }
        yield part
      }
      ##
      ## If the Body responds to #close, it will be called after iteration.
      # XXX howto: assert("Body has not been closed") { @closed }

      ##
      ## The Body commonly is an Array of Strings, the application
      ## instance itself, or a File-like object.
    end

    def close
      @closed = true
      @body.close  if @body.respond_to?(:close)
    end

    # :startdoc:

  end
end

## == Thanks
## Some parts of this specification are adopted from PEP333: Python
## Web Server Gateway Interface
## v1.0 (http://www.python.org/dev/peps/pep-0333/). I'd like to thank
## everyone involved in that effort.
