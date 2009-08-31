module ActionDispatch
  class TestRequest < Request
    # Improve version of Multipart thats in rack/master
    module Multipart #:nodoc:
      class UploadedFile
        # The filename, *not* including the path, of the "uploaded" file
        attr_reader :original_filename

        # The content type of the "uploaded" file
        attr_accessor :content_type

        def initialize(path, content_type = "text/plain", binary = false)
          raise "#{path} file does not exist" unless ::File.exist?(path)
          @content_type = content_type
          @original_filename = ::File.basename(path)
          @tempfile = Tempfile.new(@original_filename)
          @tempfile.set_encoding(Encoding::BINARY) if @tempfile.respond_to?(:set_encoding)
          @tempfile.binmode if binary
          FileUtils.copy_file(path, @tempfile.path)
        end

        def path
          @tempfile.path
        end
        alias_method :local_path, :path

        def method_missing(method_name, *args, &block) #:nodoc:
          @tempfile.__send__(method_name, *args, &block)
        end
      end

      EOL = "\r\n"
      MULTIPART_BOUNDARY = "AaB03x"

      def self.parse_multipart(env)
        unless env['CONTENT_TYPE'] =~
            %r|\Amultipart/.*boundary=\"?([^\";,]+)\"?|n
          nil
        else
          boundary = "--#{$1}"

          params = {}
          buf = ""
          content_length = env['CONTENT_LENGTH'].to_i
          input = env['rack.input']
          input.rewind

          boundary_size = Utils.bytesize(boundary) + EOL.size
          bufsize = 16384

          content_length -= boundary_size

          read_buffer = ''

          status = input.read(boundary_size, read_buffer)
          raise EOFError, "bad content body"  unless status == boundary + EOL

          rx = /(?:#{EOL})?#{Regexp.quote boundary}(#{EOL}|--)/n

          loop {
            head = nil
            body = ''
            filename = content_type = name = nil

            until head && buf =~ rx
              if !head && i = buf.index(EOL+EOL)
                head = buf.slice!(0, i+2) # First \r\n
                buf.slice!(0, 2)          # Second \r\n

                filename = head[/Content-Disposition:.* filename="?([^\";]*)"?/ni, 1]
                content_type = head[/Content-Type: (.*)#{EOL}/ni, 1]
                name = head[/Content-Disposition:.*\s+name="?([^\";]*)"?/ni, 1] || head[/Content-ID:\s*([^#{EOL}]*)/ni, 1]

                if content_type || filename
                  body = Tempfile.new("RackMultipart")
                  body.binmode  if body.respond_to?(:binmode)
                end

                next
              end

              # Save the read body part.
              if head && (boundary_size+4 < buf.size)
                body << buf.slice!(0, buf.size - (boundary_size+4))
              end

              c = input.read(bufsize < content_length ? bufsize : content_length, read_buffer)
              raise EOFError, "bad content body"  if c.nil? || c.empty?
              buf << c
              content_length -= c.size
            end

            # Save the rest.
            if i = buf.index(rx)
              body << buf.slice!(0, i)
              buf.slice!(0, boundary_size+2)

              content_length = -1  if $1 == "--"
            end

            if filename == ""
              # filename is blank which means no file has been selected
              data = nil
            elsif filename
              body.rewind

              # Take the basename of the upload's original filename.
              # This handles the full Windows paths given by Internet Explorer
              # (and perhaps other broken user agents) without affecting
              # those which give the lone filename.
              filename =~ /^(?:.*[:\\\/])?(.*)/m
              filename = $1

              data = {:filename => filename, :type => content_type,
                      :name => name, :tempfile => body, :head => head}
            elsif !filename && content_type
              body.rewind

              # Generic multipart cases, not coming from a form
              data = {:type => content_type,
                      :name => name, :tempfile => body, :head => head}
            else
              data = body
            end

            Utils.normalize_params(params, name, data) unless data.nil?

            break  if buf.empty? || content_length == -1
          }

          input.rewind

          params
        end
      end

      def self.build_multipart(params, first = true)
        if first
          unless params.is_a?(Hash)
            raise ArgumentError, "value must be a Hash"
          end

          multipart = false
          query = lambda { |value|
            case value
            when Array
              value.each(&query)
            when Hash
              value.values.each(&query)
            when UploadedFile
              multipart = true
            end
          }
          params.values.each(&query)
          return nil unless multipart
        end

        flattened_params = Hash.new

        params.each do |key, value|
          k = first ? key.to_s : "[#{key}]"

          case value
          when Array
            value.map { |v|
              build_multipart(v, false).each { |subkey, subvalue|
                flattened_params["#{k}[]#{subkey}"] = subvalue
              }
            }
          when Hash
            build_multipart(value, false).each { |subkey, subvalue|
              flattened_params[k + subkey] = subvalue
            }
          else
            flattened_params[k] = value
          end
        end

        if first
          flattened_params.map { |name, file|
            if file.respond_to?(:original_filename)
              ::File.open(file.path, "rb") do |f|
                f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)
<<-EOF
--#{MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{name}"; filename="#{Rack::Utils.escape(file.original_filename)}"\r
Content-Type: #{file.content_type}\r
Content-Length: #{::File.stat(file.path).size}\r
\r
#{f.read}\r
EOF
              end
            else
<<-EOF
--#{MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{name}"\r
\r
#{file}\r
EOF
            end
          }.join + "--#{MULTIPART_BOUNDARY}--\r"
        else
          flattened_params
        end
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

    # Improve version of env_for thats in rack/master
    def self.env_for(uri="", opts={}) #:nodoc:
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
          params = Rack::Utils.parse_nested_query(params) if params.is_a?(String)
          params.update(Rack::Utils.parse_nested_query(env["QUERY_STRING"]))
          env["QUERY_STRING"] = build_nested_query(params)
        elsif !opts.has_key?(:input)
          opts["CONTENT_TYPE"] = "application/x-www-form-urlencoded"
          if params.is_a?(Hash)
            if data = Multipart.build_multipart(params)
              opts[:input] = data
              opts["CONTENT_LENGTH"] ||= data.length.to_s
              opts["CONTENT_TYPE"] = "multipart/form-data; boundary=#{Multipart::MULTIPART_BOUNDARY}"
            else
              opts[:input] = build_nested_query(params)
            end
          else
            opts[:input] = params
          end
        end
      end

      empty_str = ""
      empty_str.force_encoding("ASCII-8BIT") if empty_str.respond_to? :force_encoding
      opts[:input] ||= empty_str
      if String === opts[:input]
        rack_input = StringIO.new(opts[:input])
      else
        rack_input = opts[:input]
      end

      rack_input.set_encoding(Encoding::BINARY) if rack_input.respond_to?(:set_encoding)
      env['rack.input'] = rack_input

      env["CONTENT_LENGTH"] ||= env["rack.input"].length.to_s

      opts.each { |field, value|
        env[field] = value  if String === field
      }

      env
    end

    def self.build_nested_query(value, prefix = nil)
      case value
      when Array
        value.map { |v|
          build_nested_query(v, "#{prefix}[]")
        }.join("&")
      when Hash
        value.map { |k, v|
          build_nested_query(v, prefix ? "#{prefix}[#{Rack::Utils.escape(k)}]" : Rack::Utils.escape(k))
        }.join("&")
      when String
        raise ArgumentError, "value must be a Hash" if prefix.nil?
        "#{prefix}=#{Rack::Utils.escape(value)}"
      else
        prefix
      end
    end

    def self.new(env = {})
      super
    end

    def initialize(env = {})
      super(self.class.env_for('/').merge(env))

      self.host        = 'test.host'
      self.remote_addr = '0.0.0.0'
      self.user_agent  = 'Rails Testing'
    end

    def env
      write_cookies!
      delete_nil_values!
      super
    end

    def request_method=(method)
      @env['REQUEST_METHOD'] = method.to_s.upcase
    end

    def host=(host)
      @env['HTTP_HOST'] = host
    end

    def port=(number)
      @env['SERVER_PORT'] = number.to_i
    end

    def request_uri=(uri)
      @env['REQUEST_URI'] = uri
    end

    def path=(path)
      @env['PATH_INFO'] = path
    end

    def action=(action_name)
      path_parameters["action"] = action_name.to_s
    end

    def if_modified_since=(last_modified)
      @env['HTTP_IF_MODIFIED_SINCE'] = last_modified
    end

    def if_none_match=(etag)
      @env['HTTP_IF_NONE_MATCH'] = etag
    end

    def remote_addr=(addr)
      @env['REMOTE_ADDR'] = addr
    end

    def user_agent=(user_agent)
      @env['HTTP_USER_AGENT'] = user_agent
    end

    def accept=(mime_types)
      @env.delete('action_dispatch.request.accepts')
      @env['HTTP_ACCEPT'] = Array(mime_types).collect { |mime_types| mime_types.to_s }.join(",")
    end

    def cookies
      @cookies ||= super
    end

    private
      def write_cookies!
        unless @cookies.blank?
          @env['HTTP_COOKIE'] = @cookies.map { |name, value| "#{name}=#{value};" }.join(' ')
        end
      end

      def delete_nil_values!
        @env.delete_if { |k, v| v.nil? }
      end
  end
end
