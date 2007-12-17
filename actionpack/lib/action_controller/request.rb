require 'tempfile'
require 'stringio'
require 'strscan'

module ActionController
  # HTTP methods which are accepted by default. 
  ACCEPTED_HTTP_METHODS = Set.new(%w( get head put post delete options ))

  # CgiRequest and TestRequest provide concrete implementations.
  class AbstractRequest
    cattr_accessor :relative_url_root
    remove_method :relative_url_root

    # The hash of environment variables for this request,
    # such as { 'RAILS_ENV' => 'production' }.
    attr_reader :env

    # The true HTTP request method as a lowercase symbol, such as :get.
    # UnknownHttpMethod is raised for invalid methods not listed in ACCEPTED_HTTP_METHODS.
    def request_method
      @request_method ||= begin
        method = ((@env['REQUEST_METHOD'] == 'POST' && !parameters[:_method].blank?) ? parameters[:_method].to_s : @env['REQUEST_METHOD']).downcase
        if ACCEPTED_HTTP_METHODS.include?(method)
          method.to_sym
        else
          raise UnknownHttpMethod, "#{method}, accepted HTTP methods are #{ACCEPTED_HTTP_METHODS.to_a.to_sentence}"
        end
      end
    end

    # The HTTP request method as a lowercase symbol, such as :get.
    # Note, HEAD is returned as :get since the two are functionally
    # equivalent from the application's perspective.
    def method
      request_method == :head ? :get : request_method
    end

    # Is this a GET (or HEAD) request?  Equivalent to request.method == :get
    def get?
      method == :get
    end

    # Is this a POST request?  Equivalent to request.method == :post
    def post?
      request_method == :post
    end

    # Is this a PUT request?  Equivalent to request.method == :put
    def put?
      request_method == :put
    end

    # Is this a DELETE request?  Equivalent to request.method == :delete
    def delete?
      request_method == :delete
    end

    # Is this a HEAD request? request.method sees HEAD as :get, so check the
    # HTTP method directly.
    def head?
      request_method == :head
    end

    def headers
      @env
    end

    def content_length
      @content_length ||= env['CONTENT_LENGTH'].to_i
    end

    # The MIME type of the HTTP request, such as Mime::XML.
    #
    # For backward compatibility, the post format is extracted from the
    # X-Post-Data-Format HTTP header if present.
    def content_type
      @content_type ||= Mime::Type.lookup(content_type_without_parameters)
    end

    # Returns the accepted MIME type for the request
    def accepts
      @accepts ||=
        if @env['HTTP_ACCEPT'].to_s.strip.empty?
          [ content_type, Mime::ALL ].compact # make sure content_type being nil is not included
        else
          Mime::Type.parse(@env['HTTP_ACCEPT'])
        end
    end

    # Returns the Mime type for the format used in the request. If there is no format available, the first of the 
    # accept types will be used. Examples:
    #
    #   GET /posts/5.xml   | request.format => Mime::XML
    #   GET /posts/5.xhtml | request.format => Mime::HTML
    #   GET /posts/5       | request.format => request.accepts.first (usually Mime::HTML for browsers)
    def format
      @format ||= parameters[:format] ? Mime::Type.lookup_by_extension(parameters[:format]) : accepts.first
    end
    
    
    # Sets the format by string extension, which can be used to force custom formats that are not controlled by the extension.
    # Example:
    #
    #   class ApplicationController < ActionController::Base
    #     before_filter :adjust_format_for_iphone
    #   
    #     private
    #       def adjust_format_for_iphone
    #         request.format = :iphone if request.env["HTTP_USER_AGENT"][/iPhone/]
    #       end
    #   end
    def format=(extension)
      parameters[:format] = extension.to_s
      format
    end

    # Returns true if the request's "X-Requested-With" header contains
    # "XMLHttpRequest". (The Prototype Javascript library sends this header with
    # every Ajax request.)
    def xml_http_request?
      !(@env['HTTP_X_REQUESTED_WITH'] !~ /XMLHttpRequest/i)
    end
    alias xhr? :xml_http_request?

    # Determine originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these before
    # falling back to REMOTE_ADDR.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the first is
    # the originating IP.
    #
    # Security note: do not use if IP spoofing is a concern for your
    # application. Since remote_ip checks HTTP headers for addresses forwarded
    # by proxies, the client may send any IP. remote_addr can't be spoofed but
    # also doesn't work behind a proxy, since it's always the proxy's IP.
    def remote_ip
      return @env['HTTP_CLIENT_IP'] if @env.include? 'HTTP_CLIENT_IP'

      if @env.include? 'HTTP_X_FORWARDED_FOR' then
        remote_ips = @env['HTTP_X_FORWARDED_FOR'].split(',').reject do |ip|
          ip.strip =~ /^unknown$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\./i
        end

        return remote_ips.first.strip unless remote_ips.empty?
      end

      @env['REMOTE_ADDR']
    end

    # Returns the lowercase name of the HTTP server software.
    def server_software
      (@env['SERVER_SOFTWARE'] && /^([a-zA-Z]+)/ =~ @env['SERVER_SOFTWARE']) ? $1.downcase : nil
    end


    # Returns the complete URL used for this request
    def url
      protocol + host_with_port + request_uri
    end

    # Return 'https://' if this is an SSL request and 'http://' otherwise.
    def protocol
      ssl? ? 'https://' : 'http://'
    end

    # Is this an SSL request?
    def ssl?
      @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https'
    end

    # Returns the host for this request, such as example.com.
    def host
    end

    # Returns a host:port string for this request, such as example.com or
    # example.com:8080.
    def host_with_port
      @host_with_port ||= host + port_string
    end

    # Returns the port number of this request as an integer.
    def port
      @port_as_int ||= @env['SERVER_PORT'].to_i
    end

    # Returns the standard port number for this request's protocol
    def standard_port
      case protocol
        when 'https://' then 443
        else 80
      end
    end

    # Returns a port suffix like ":8080" if the port number of this request
    # is not the default HTTP port 80 or HTTPS port 443.
    def port_string
      (port == standard_port) ? '' : ":#{port}"
    end

    # Returns the domain part of a host, such as rubyonrails.org in "www.rubyonrails.org". You can specify
    # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
    def domain(tld_length = 1)
      return nil unless named_host?(host)

      host.split('.').last(1 + tld_length).join('.')
    end

    # Returns all the subdomains as an array, so ["dev", "www"] would be returned for "dev.www.rubyonrails.org".
    # You can specify a different <tt>tld_length</tt>, such as 2 to catch ["www"] instead of ["www", "rubyonrails"]
    # in "www.rubyonrails.co.uk".
    def subdomains(tld_length = 1)
      return [] unless named_host?(host)
      parts = host.split('.')
      parts[0..-(tld_length+2)]
    end

    # Return the query string, accounting for server idiosyncracies.
    def query_string
      if uri = @env['REQUEST_URI']
        uri.split('?', 2)[1] || ''
      else
        @env['QUERY_STRING'] || ''
      end
    end

    # Return the request URI, accounting for server idiosyncracies.
    # WEBrick includes the full URL. IIS leaves REQUEST_URI blank.
    def request_uri
      if uri = @env['REQUEST_URI']
        # Remove domain, which webrick puts into the request_uri.
        (%r{^\w+\://[^/]+(/.*|$)$} =~ uri) ? $1 : uri
      else
        # Construct IIS missing REQUEST_URI from SCRIPT_NAME and PATH_INFO.
        script_filename = @env['SCRIPT_NAME'].to_s.match(%r{[^/]+$})
        uri = @env['PATH_INFO']
        uri = uri.sub(/#{script_filename}\//, '') unless script_filename.nil?
        unless (env_qs = @env['QUERY_STRING']).nil? || env_qs.empty?
          uri << '?' << env_qs
        end

        if uri.nil?
          @env.delete('REQUEST_URI')
          uri
        else
          @env['REQUEST_URI'] = uri
        end
      end
    end

    # Returns the interpreted path to requested resource after all the installation directory of this application was taken into account
    def path
      path = (uri = request_uri) ? uri.split('?').first.to_s : ''

      # Cut off the path to the installation directory if given
      path.sub!(%r/^#{relative_url_root}/, '')
      path || ''      
    end
    
    # Returns the path minus the web server relative installation directory.
    # This can be set with the environment variable RAILS_RELATIVE_URL_ROOT.
    # It can be automatically extracted for Apache setups. If the server is not
    # Apache, this method returns an empty string.
    def relative_url_root
      @@relative_url_root ||= case
        when @env["RAILS_RELATIVE_URL_ROOT"]
          @env["RAILS_RELATIVE_URL_ROOT"]
        when server_software == 'apache'
          @env["SCRIPT_NAME"].to_s.sub(/\/dispatch\.(fcgi|rb|cgi)$/, '')
        else
          ''
      end
    end


    # Read the request body. This is useful for web services that need to
    # work with raw requests directly.
    def raw_post
      unless env.include? 'RAW_POST_DATA'
        env['RAW_POST_DATA'] = body.read(content_length)
        body.rewind if body.respond_to?(:rewind)
      end
      env['RAW_POST_DATA']
    end

    # Returns both GET and POST parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.merge(query_parameters).update(path_parameters).with_indifferent_access
    end

    def path_parameters=(parameters) #:nodoc:
      @path_parameters = parameters
      @symbolized_path_parameters = @parameters = nil
    end

    # The same as <tt>path_parameters</tt> with explicitly symbolized keys 
    def symbolized_path_parameters 
      @symbolized_path_parameters ||= path_parameters.symbolize_keys
    end

    # Returns a hash with the parameters used to form the path of the request.
    # Returned hash keys are strings.  See <tt>symbolized_path_parameters</tt> for symbolized keys.
    #
    # Example: 
    #
    #   {'action' => 'my_action', 'controller' => 'my_controller'}
    def path_parameters
      @path_parameters ||= {}
    end


    #--
    # Must be implemented in the concrete request
    #++

    # The request body is an IO input stream.
    def body
    end

    def query_parameters #:nodoc:
    end

    def request_parameters #:nodoc:
    end

    def cookies #:nodoc:
    end

    def session #:nodoc:
    end

    def session=(session) #:nodoc:
      @session = session
    end

    def reset_session #:nodoc:
    end

    protected
      # The raw content type string. Use when you need parameters such as
      # charset or boundary which aren't included in the content_type MIME type.
      # Overridden by the X-POST_DATA_FORMAT header for backward compatibility.
      def content_type_with_parameters
        content_type_from_legacy_post_data_format_header ||
          env['CONTENT_TYPE'].to_s
      end

      # The raw content type string with its parameters stripped off.
      def content_type_without_parameters
        @content_type_without_parameters ||= self.class.extract_content_type_without_parameters(content_type_with_parameters)
      end

    private
      def content_type_from_legacy_post_data_format_header
        if x_post_format = @env['HTTP_X_POST_DATA_FORMAT']
          case x_post_format.to_s.downcase
            when 'yaml';  'application/x-yaml'
            when 'xml';   'application/xml'
          end
        end
      end

      def parse_formatted_request_parameters
        return {} if content_length.zero?

        content_type, boundary = self.class.extract_multipart_boundary(content_type_with_parameters)

        # Don't parse params for unknown requests.
        return {} if content_type.blank?

        mime_type = Mime::Type.lookup(content_type)
        strategy = ActionController::Base.param_parsers[mime_type]

        # Only multipart form parsing expects a stream.
        body = (strategy && strategy != :multipart_form) ? raw_post : self.body

        case strategy
          when Proc
            strategy.call(body)
          when :url_encoded_form
            self.class.clean_up_ajax_request_body! body
            self.class.parse_query_parameters(body)
          when :multipart_form
            self.class.parse_multipart_form_parameters(body, boundary, content_length, env)
          when :xml_simple, :xml_node
            body.blank? ? {} : Hash.from_xml(body).with_indifferent_access
          when :yaml
            YAML.load(body)
          else
            {}
        end
      rescue Exception => e # YAML, XML or Ruby code block errors
        raise
        { "body" => body,
          "content_type" => content_type_with_parameters,
          "content_length" => content_length,
          "exception" => "#{e.message} (#{e.class})",
          "backtrace" => e.backtrace }
      end

      def named_host?(host)
        !(host.nil? || /\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.match(host))
      end

    class << self
      def parse_query_parameters(query_string)
        return {} if query_string.blank?

        pairs = query_string.split('&').collect do |chunk|
          next if chunk.empty?
          key, value = chunk.split('=', 2)
          next if key.empty?
          value = value.nil? ? nil : CGI.unescape(value)
          [ CGI.unescape(key), value ]
        end.compact

        UrlEncodedPairParser.new(pairs).result
      end

      def parse_request_parameters(params)
        parser = UrlEncodedPairParser.new

        params = params.dup
        until params.empty?
          for key, value in params
            if key.blank?
              params.delete key
            elsif !key.include?('[')
              # much faster to test for the most common case first (GET)
              # and avoid the call to build_deep_hash
              parser.result[key] = get_typed_value(value[0])
              params.delete key
            elsif value.is_a?(Array)
              parser.parse(key, get_typed_value(value.shift))
              params.delete key if value.empty?
            else
              raise TypeError, "Expected array, found #{value.inspect}"
            end
          end
        end

        parser.result
      end

      def parse_multipart_form_parameters(body, boundary, content_length, env)
        parse_request_parameters(read_multipart(body, boundary, content_length, env))
      end

      def extract_multipart_boundary(content_type_with_parameters)
        if content_type_with_parameters =~ MULTIPART_BOUNDARY
          ['multipart/form-data', $1.dup]
        else
          extract_content_type_without_parameters(content_type_with_parameters)
        end
      end

      def extract_content_type_without_parameters(content_type_with_parameters)
        $1.strip.downcase if content_type_with_parameters =~ /^([^,\;]*)/
      end

      def clean_up_ajax_request_body!(body)
        body.chop! if body[-1] == 0
        body.gsub!(/&_=$/, '')
      end


      private
        def get_typed_value(value)
          case value
            when String
              value
            when NilClass
              ''
            when Array
              value.map { |v| get_typed_value(v) }
            else
              if value.is_a?(UploadedFile)
                # Uploaded file
                if value.original_filename
                  value
                # Multipart param
                else
                  result = value.read
                  value.rewind
                  result
                end
              # Unknown value, neither string nor multipart.
              else
                raise "Unknown form value: #{value.inspect}"
              end
          end
        end


        MULTIPART_BOUNDARY = %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)\"?|n

        EOL = "\015\012"

        def read_multipart(body, boundary, content_length, env)
          params = Hash.new([])
          boundary = "--" + boundary
          quoted_boundary = Regexp.quote(boundary, "n")
          buf = ""
          bufsize = 10 * 1024
          boundary_end=""

          # start multipart/form-data
          body.binmode if defined? body.binmode
          boundary_size = boundary.size + EOL.size
          content_length -= boundary_size
          status = body.read(boundary_size)
          if nil == status
            raise EOFError, "no content body"
          elsif boundary + EOL != status
            raise EOFError, "bad content body"
          end

          loop do
            head = nil
            content =
              if 10240 < content_length
                UploadedTempfile.new("CGI")
              else
                UploadedStringIO.new
              end
            content.binmode if defined? content.binmode

            until head and /#{quoted_boundary}(?:#{EOL}|--)/n.match(buf)

              if (not head) and /#{EOL}#{EOL}/n.match(buf)
                buf = buf.sub(/\A((?:.|\n)*?#{EOL})#{EOL}/n) do
                  head = $1.dup
                  ""
                end
                next
              end

              if head and ( (EOL + boundary + EOL).size < buf.size )
                content.print buf[0 ... (buf.size - (EOL + boundary + EOL).size)]
                buf[0 ... (buf.size - (EOL + boundary + EOL).size)] = ""
              end

              c = if bufsize < content_length
                    body.read(bufsize)
                  else
                    body.read(content_length)
                  end
              if c.nil? || c.empty?
                raise EOFError, "bad content body"
              end
              buf.concat(c)
              content_length -= c.size
            end

            buf = buf.sub(/\A((?:.|\n)*?)(?:[\r\n]{1,2})?#{quoted_boundary}([\r\n]{1,2}|--)/n) do
              content.print $1
              if "--" == $2
                content_length = -1
              end
             boundary_end = $2.dup
              ""
            end

            content.rewind

            head =~ /Content-Disposition:.* filename=(?:"((?:\\.|[^\"])*)"|([^;]*))/ni
            if filename = $1 || $2
              if /Mac/ni.match(env['HTTP_USER_AGENT']) and
                  /Mozilla/ni.match(env['HTTP_USER_AGENT']) and
                  (not /MSIE/ni.match(env['HTTP_USER_AGENT']))
                filename = CGI.unescape(filename)
              end
              content.original_path = filename.dup
            end

            head =~ /Content-Type: ([^\r]*)/ni
            content.content_type = $1.dup if $1

            head =~ /Content-Disposition:.* name="?([^\";]*)"?/ni
            name = $1.dup if $1

            if params.has_key?(name)
              params[name].push(content)
            else
              params[name] = [content]
            end
            break if buf.size == 0
            break if content_length == -1
          end
          raise EOFError, "bad boundary end of body part" unless boundary_end=~/--/

	  begin
            body.rewind if body.respond_to?(:rewind)
	  rescue Errno::ESPIPE
            # Handles exceptions raised by input streams that cannot be rewound
            # such as when using plain CGI under Apache
	  end

          params
        end
    end
  end

  class UrlEncodedPairParser < StringScanner #:nodoc:
    attr_reader :top, :parent, :result

    def initialize(pairs = [])
      super('')
      @result = {}
      pairs.each { |key, value| parse(key, value) }
    end

    KEY_REGEXP = %r{([^\[\]=&]+)}
    BRACKETED_KEY_REGEXP = %r{\[([^\[\]=&]+)\]}

    # Parse the query string
    def parse(key, value)
      self.string = key
      @top, @parent = result, nil

      # First scan the bare key
      key = scan(KEY_REGEXP) or return
      key = post_key_check(key)

      # Then scan as many nestings as present
      until eos?
        r = scan(BRACKETED_KEY_REGEXP) or return
        key = self[1]
        key = post_key_check(key)
      end

      bind(key, value)
    end

    private
      # After we see a key, we must look ahead to determine our next action. Cases:
      #
      #   [] follows the key. Then the value must be an array.
      #   = follows the key. (A value comes next)
      #   & or the end of string follows the key. Then the key is a flag.
      #   otherwise, a hash follows the key.
      def post_key_check(key)
        if scan(/\[\]/) # a[b][] indicates that b is an array
          container(key, Array)
          nil
        elsif check(/\[[^\]]/) # a[b] indicates that a is a hash
          container(key, Hash)
          nil
        else # End of key? We do nothing.
          key
        end
      end

      # Add a container to the stack.
      def container(key, klass)
        type_conflict! klass, top[key] if top.is_a?(Hash) && top.key?(key) && ! top[key].is_a?(klass)
        value = bind(key, klass.new)
        type_conflict! klass, value unless value.is_a?(klass)
        push(value)
      end

      # Push a value onto the 'stack', which is actually only the top 2 items.
      def push(value)
        @parent, @top = @top, value
      end

      # Bind a key (which may be nil for items in an array) to the provided value.
      def bind(key, value)
        if top.is_a? Array
          if key
            if top[-1].is_a?(Hash) && ! top[-1].key?(key)
              top[-1][key] = value
            else
              top << {key => value}.with_indifferent_access
              push top.last
            end
          else
            top << value
          end
        elsif top.is_a? Hash
          key = CGI.unescape(key)
          parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
          return top[key] ||= value
        else
          raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
        end

        return value
      end

      def type_conflict!(klass, value)
        raise TypeError, "Conflicting types for parameter containers. Expected an instance of #{klass} but found an instance of #{value.class}. This can be caused by colliding Array and Hash parameters like qs[]=value&qs[key]=value."
      end
  end

  module UploadedFile
    def self.included(base)
      base.class_eval do
        attr_accessor :original_path, :content_type
        alias_method :local_path, :path
      end
    end

    # Take the basename of the upload's original filename.
    # This handles the full Windows paths given by Internet Explorer
    # (and perhaps other broken user agents) without affecting
    # those which give the lone filename.
    # The Windows regexp is adapted from Perl's File::Basename.
    def original_filename
      unless defined? @original_filename
        @original_filename =
          unless original_path.blank?
            if original_path =~ /^(?:.*[:\\\/])?(.*)/m
              $1
            else
              File.basename original_path
            end
          end
      end
      @original_filename
    end
  end

  class UploadedStringIO < StringIO
    include UploadedFile
  end

  class UploadedTempfile < Tempfile
    include UploadedFile
  end
end
