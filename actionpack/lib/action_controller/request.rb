require 'tempfile'
require 'stringio'
require 'strscan'

require 'active_support/memoizable'

module ActionController
  # CgiRequest and TestRequest provide concrete implementations.
  class AbstractRequest
    extend ActiveSupport::Memoizable

    def self.relative_url_root=(relative_url_root)
      ActiveSupport::Deprecation.warn(
        "ActionController::AbstractRequest.relative_url_root= has been renamed." +
        "You can now set it with config.action_controller.relative_url_root=", caller)
      ActionController::Base.relative_url_root=relative_url_root
    end

    HTTP_METHODS = %w(get head put post delete options)
    HTTP_METHOD_LOOKUP = HTTP_METHODS.inject({}) { |h, m| h[m] = h[m.upcase] = m.to_sym; h }

    # The hash of environment variables for this request,
    # such as { 'RAILS_ENV' => 'production' }.
    attr_reader :env

    # The true HTTP request \method as a lowercase symbol, such as <tt>:get</tt>.
    # UnknownHttpMethod is raised for invalid methods not listed in ACCEPTED_HTTP_METHODS.
    def request_method
      method = @env['REQUEST_METHOD']
      method = parameters[:_method] if method == 'POST' && !parameters[:_method].blank?

      HTTP_METHOD_LOOKUP[method] || raise(UnknownHttpMethod, "#{method}, accepted HTTP methods are #{HTTP_METHODS.to_sentence}")
    end
    memoize :request_method

    # The HTTP request \method as a lowercase symbol, such as <tt>:get</tt>.
    # Note, HEAD is returned as <tt>:get</tt> since the two are functionally
    # equivalent from the application's perspective.
    def method
      request_method == :head ? :get : request_method
    end

    # Is this a GET (or HEAD) request?  Equivalent to <tt>request.method == :get</tt>.
    def get?
      method == :get
    end

    # Is this a POST request?  Equivalent to <tt>request.method == :post</tt>.
    def post?
      request_method == :post
    end

    # Is this a PUT request?  Equivalent to <tt>request.method == :put</tt>.
    def put?
      request_method == :put
    end

    # Is this a DELETE request?  Equivalent to <tt>request.method == :delete</tt>.
    def delete?
      request_method == :delete
    end

    # Is this a HEAD request? Since <tt>request.method</tt> sees HEAD as <tt>:get</tt>,
    # this \method checks the actual HTTP \method directly.
    def head?
      request_method == :head
    end

    # Provides access to the request's HTTP headers, for example:
    #
    #   request.headers["Content-Type"] # => "text/plain"
    def headers
      ActionController::Http::Headers.new(@env)
    end
    memoize :headers

    # Returns the content length of the request as an integer.
    def content_length
      @env['CONTENT_LENGTH'].to_i
    end
    memoize :content_length

    # The MIME type of the HTTP request, such as Mime::XML.
    #
    # For backward compatibility, the post \format is extracted from the
    # X-Post-Data-Format HTTP header if present.
    def content_type
      Mime::Type.lookup(content_type_without_parameters)
    end
    memoize :content_type

    # Returns the accepted MIME type for the request.
    def accepts
      header = @env['HTTP_ACCEPT'].to_s.strip

      if header.empty?
        [content_type, Mime::ALL].compact
      else
        Mime::Type.parse(header)
      end
    end
    memoize :accepts

    def if_modified_since
      if since = env['HTTP_IF_MODIFIED_SINCE']
        Time.rfc2822(since) rescue nil
      end
    end
    memoize :if_modified_since

    def if_none_match
      env['HTTP_IF_NONE_MATCH']
    end

    def not_modified?(modified_at)
      if_modified_since && modified_at && if_modified_since >= modified_at
    end

    def etag_matches?(etag)
      if_none_match && if_none_match == etag
    end

    # Check response freshness (Last-Modified and ETag) against request
    # If-Modified-Since and If-None-Match conditions. If both headers are
    # supplied, both must match, or the request is not considered fresh.
    def fresh?(response)
      case
      when if_modified_since && if_none_match 
        not_modified?(response.last_modified) && etag_matches?(response.etag) 
      when if_modified_since 
        not_modified?(response.last_modified) 
      when if_none_match 
        etag_matches?(response.etag) 
      else 
        false 
      end 
    end

    # Returns the Mime type for the \format used in the request.
    #
    #   GET /posts/5.xml   | request.format => Mime::XML
    #   GET /posts/5.xhtml | request.format => Mime::HTML
    #   GET /posts/5       | request.format => Mime::HTML or MIME::JS, or request.accepts.first depending on the value of <tt>ActionController::Base.use_accept_header</tt>
    def format
      @format ||=
        if parameters[:format]
          Mime::Type.lookup_by_extension(parameters[:format])
        elsif ActionController::Base.use_accept_header
          accepts.first
        elsif xhr?
          Mime::Type.lookup_by_extension("js")
        else
          Mime::Type.lookup_by_extension("html")
        end
    end


    # Sets the \format by string extension, which can be used to force custom formats
    # that are not controlled by the extension.
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
      @format = Mime::Type.lookup_by_extension(parameters[:format])
    end

    # Returns a symbolized version of the <tt>:format</tt> parameter of the request.
    # If no \format is given it returns <tt>:js</tt>for Ajax requests and <tt>:html</tt>
    # otherwise.
    def template_format
      parameter_format = parameters[:format]

      if parameter_format
        parameter_format
      elsif xhr?
        :js
      else
        :html
      end
    end

    def cache_format
      parameters[:format]
    end

    # Returns true if the request's "X-Requested-With" header contains
    # "XMLHttpRequest". (The Prototype Javascript library sends this header with
    # every Ajax request.)
    def xml_http_request?
      !(@env['HTTP_X_REQUESTED_WITH'] !~ /XMLHttpRequest/i)
    end
    alias xhr? :xml_http_request?

    # Which IP addresses are "trusted proxies" that can be stripped from
    # the right-hand-side of X-Forwarded-For
    TRUSTED_PROXIES = /^127\.0\.0\.1$|^(10|172\.(1[6-9]|2[0-9]|30|31)|192\.168)\./i

    # Determines originating IP address.  REMOTE_ADDR is the standard
    # but will fail if the user is behind a proxy.  HTTP_CLIENT_IP and/or
    # HTTP_X_FORWARDED_FOR are set by proxies so check for these if
    # REMOTE_ADDR is a proxy.  HTTP_X_FORWARDED_FOR may be a comma-
    # delimited list in the case of multiple chained proxies; the last
    # address which is not trusted is the originating IP.
    def remote_ip
      remote_addr_list = @env['REMOTE_ADDR'] && @env['REMOTE_ADDR'].split(',').collect(&:strip)

      unless remote_addr_list.blank?
        not_trusted_addrs = remote_addr_list.reject {|addr| addr =~ TRUSTED_PROXIES}
        return not_trusted_addrs.first unless not_trusted_addrs.empty?
      end
      remote_ips = @env['HTTP_X_FORWARDED_FOR'] && @env['HTTP_X_FORWARDED_FOR'].split(',')

      if @env.include? 'HTTP_CLIENT_IP'
        if remote_ips && !remote_ips.include?(@env['HTTP_CLIENT_IP'])
          # We don't know which came from the proxy, and which from the user
          raise ActionControllerError.new(<<EOM)
IP spoofing attack?!
HTTP_CLIENT_IP=#{@env['HTTP_CLIENT_IP'].inspect}
HTTP_X_FORWARDED_FOR=#{@env['HTTP_X_FORWARDED_FOR'].inspect}
EOM
        end

        return @env['HTTP_CLIENT_IP']
      end

      if remote_ips
        while remote_ips.size > 1 && TRUSTED_PROXIES =~ remote_ips.last.strip
          remote_ips.pop
        end

        return remote_ips.last.strip
      end

      @env['REMOTE_ADDR']
    end
    memoize :remote_ip

    # Returns the lowercase name of the HTTP server software.
    def server_software
      (@env['SERVER_SOFTWARE'] && /^([a-zA-Z]+)/ =~ @env['SERVER_SOFTWARE']) ? $1.downcase : nil
    end
    memoize :server_software


    # Returns the complete URL used for this request.
    def url
      protocol + host_with_port + request_uri
    end
    memoize :url

    # Returns 'https://' if this is an SSL request and 'http://' otherwise.
    def protocol
      ssl? ? 'https://' : 'http://'
    end
    memoize :protocol

    # Is this an SSL request?
    def ssl?
      @env['HTTPS'] == 'on' || @env['HTTP_X_FORWARDED_PROTO'] == 'https'
    end

    # Returns the \host for this request, such as "example.com".
    def raw_host_with_port
      if forwarded = env["HTTP_X_FORWARDED_HOST"]
        forwarded.split(/,\s?/).last
      else
        env['HTTP_HOST'] || env['SERVER_NAME'] || "#{env['SERVER_ADDR']}:#{env['SERVER_PORT']}"
      end
    end

    # Returns the host for this request, such as example.com.
    def host
      raw_host_with_port.sub(/:\d+$/, '')
    end
    memoize :host

    # Returns a \host:\port string for this request, such as "example.com" or
    # "example.com:8080".
    def host_with_port
      "#{host}#{port_string}"
    end
    memoize :host_with_port

    # Returns the port number of this request as an integer.
    def port
      if raw_host_with_port =~ /:(\d+)$/
        $1.to_i
      else
        standard_port
      end
    end
    memoize :port

    # Returns the standard \port number for this request's protocol.
    def standard_port
      case protocol
        when 'https://' then 443
        else 80
      end
    end

    # Returns a \port suffix like ":8080" if the \port number of this request
    # is not the default HTTP \port 80 or HTTPS \port 443.
    def port_string
      port == standard_port ? '' : ":#{port}"
    end

    # Returns the \domain part of a \host, such as "rubyonrails.org" in "www.rubyonrails.org". You can specify
    # a different <tt>tld_length</tt>, such as 2 to catch rubyonrails.co.uk in "www.rubyonrails.co.uk".
    def domain(tld_length = 1)
      return nil unless named_host?(host)

      host.split('.').last(1 + tld_length).join('.')
    end

    # Returns all the \subdomains as an array, so <tt>["dev", "www"]</tt> would be
    # returned for "dev.www.rubyonrails.org". You can specify a different <tt>tld_length</tt>,
    # such as 2 to catch <tt>["www"]</tt> instead of <tt>["www", "rubyonrails"]</tt>
    # in "www.rubyonrails.co.uk".
    def subdomains(tld_length = 1)
      return [] unless named_host?(host)
      parts = host.split('.')
      parts[0..-(tld_length+2)]
    end

    # Returns the query string, accounting for server idiosyncrasies.
    def query_string
      if uri = @env['REQUEST_URI']
        uri.split('?', 2)[1] || ''
      else
        @env['QUERY_STRING'] || ''
      end
    end
    memoize :query_string

    # Returns the request URI, accounting for server idiosyncrasies.
    # WEBrick includes the full URL. IIS leaves REQUEST_URI blank.
    def request_uri
      if uri = @env['REQUEST_URI']
        # Remove domain, which webrick puts into the request_uri.
        (%r{^\w+\://[^/]+(/.*|$)$} =~ uri) ? $1 : uri
      else
        # Construct IIS missing REQUEST_URI from SCRIPT_NAME and PATH_INFO.
        uri = @env['PATH_INFO'].to_s

        if script_filename = @env['SCRIPT_NAME'].to_s.match(%r{[^/]+$})
          uri = uri.sub(/#{script_filename}\//, '')
        end

        env_qs = @env['QUERY_STRING'].to_s
        uri += "?#{env_qs}" unless env_qs.empty?

        if uri.blank?
          @env.delete('REQUEST_URI')
        else
          @env['REQUEST_URI'] = uri
        end
      end
    end
    memoize :request_uri

    # Returns the interpreted \path to requested resource after all the installation
    # directory of this application was taken into account.
    def path
      path = (uri = request_uri) ? uri.split('?').first.to_s : ''

      # Cut off the path to the installation directory if given
      path.sub!(%r/^#{ActionController::Base.relative_url_root}/, '')
      path || ''
    end
    memoize :path

    # Read the request \body. This is useful for web services that need to
    # work with raw requests directly.
    def raw_post
      unless env.include? 'RAW_POST_DATA'
        env['RAW_POST_DATA'] = body.read(content_length)
        body.rewind if body.respond_to?(:rewind)
      end
      env['RAW_POST_DATA']
    end

    # Returns both GET and POST \parameters in a single hash.
    def parameters
      @parameters ||= request_parameters.merge(query_parameters).update(path_parameters).with_indifferent_access
    end

    def path_parameters=(parameters) #:nodoc:
      @path_parameters = parameters
      @symbolized_path_parameters = @parameters = nil
    end

    # The same as <tt>path_parameters</tt> with explicitly symbolized keys.
    def symbolized_path_parameters
      @symbolized_path_parameters ||= path_parameters.symbolize_keys
    end

    # Returns a hash with the \parameters used to form the \path of the request.
    # Returned hash keys are strings:
    #
    #   {'action' => 'my_action', 'controller' => 'my_controller'}
    #
    # See <tt>symbolized_path_parameters</tt> for symbolized keys.
    def path_parameters
      @path_parameters ||= {}
    end

    # The request body is an IO input stream. If the RAW_POST_DATA environment
    # variable is already set, wrap it in a StringIO.
    def body
      if raw_post = env['RAW_POST_DATA']
        raw_post.force_encoding(Encoding::BINARY) if raw_post.respond_to?(:force_encoding)
        StringIO.new(raw_post)
      else
        body_stream
      end
    end

    def remote_addr
      @env['REMOTE_ADDR']
    end

    def referrer
      @env['HTTP_REFERER']
    end
    alias referer referrer


    def query_parameters
      @query_parameters ||= self.class.parse_query_parameters(query_string)
    end

    def request_parameters
      @request_parameters ||= parse_formatted_request_parameters
    end


    #--
    # Must be implemented in the concrete request
    #++

    def body_stream #:nodoc:
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
        self.class.extract_content_type_without_parameters(content_type_with_parameters)
      end
      memoize :content_type_without_parameters

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
          when :json
            if body.blank?
              {}
            else
              data = ActiveSupport::JSON.decode(body)
              data = {:_json => data} unless data.is_a?(Hash)
              data.with_indifferent_access
            end
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

      def parse_multipart_form_parameters(body, boundary, body_size, env)
        parse_request_parameters(read_multipart(body, boundary, body_size, env))
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
              if value.respond_to? :original_filename
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

        def read_multipart(body, boundary, body_size, env)
          params = Hash.new([])
          boundary = "--" + boundary
          quoted_boundary = Regexp.quote(boundary)
          buf = ""
          bufsize = 10 * 1024
          boundary_end=""

          # start multipart/form-data
          body.binmode if defined? body.binmode
          case body
          when File
            body.set_encoding(Encoding::BINARY) if body.respond_to?(:set_encoding)
          when StringIO
            body.string.force_encoding(Encoding::BINARY) if body.string.respond_to?(:force_encoding)
          end
          boundary_size = boundary.size + EOL.size
          body_size -= boundary_size
          status = body.read(boundary_size)
          if nil == status
            raise EOFError, "no content body"
          elsif boundary + EOL != status
            raise EOFError, "bad content body"
          end

          loop do
            head = nil
            content =
              if 10240 < body_size
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

              c = if bufsize < body_size
                    body.read(bufsize)
                  else
                    body.read(body_size)
                  end
              if c.nil? || c.empty?
                raise EOFError, "bad content body"
              end
              buf.concat(c)
              body_size -= c.size
            end

            buf = buf.sub(/\A((?:.|\n)*?)(?:[\r\n]{1,2})?#{quoted_boundary}([\r\n]{1,2}|--)/n) do
              content.print $1
              if "--" == $2
                body_size = -1
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
            break if body_size == -1
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
              value = top[key]
            end
          else
            top << value
          end
        elsif top.is_a? Hash
          key = CGI.unescape(key)
          parent << (@top = {}) if top.key?(key) && parent.is_a?(Array)
          top[key] ||= value
          return top[key]
        else
          raise ArgumentError, "Don't know what to do: top is #{top.inspect}"
        end

        return value
      end

      def type_conflict!(klass, value)
        raise TypeError, "Conflicting types for parameter containers. Expected an instance of #{klass} but found an instance of #{value.class}. This can be caused by colliding Array and Hash parameters like qs[]=value&qs[key]=value. (The parameters received were #{value.inspect}.)"
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
