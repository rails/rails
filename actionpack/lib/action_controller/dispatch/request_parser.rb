module ActionController
  class RequestParser
    def initialize(env)
      @env = env
      freeze
    end

    def request_parameters
      @env["action_controller.request_parser.request_parameters"] ||= parse_formatted_request_parameters
    end

    def query_parameters
      @env["action_controller.request_parser.query_parameters"] ||= self.class.parse_query_parameters(query_string)
    end

    # Returns the query string, accounting for server idiosyncrasies.
    def query_string
      @env['QUERY_STRING'].present? ? @env['QUERY_STRING'] : (@env['REQUEST_URI'].split('?', 2)[1] || '')
    end

    # The request body is an IO input stream. If the RAW_POST_DATA environment
    # variable is already set, wrap it in a StringIO.
    def body
      if raw_post = @env['RAW_POST_DATA']
        raw_post.force_encoding(Encoding::BINARY) if raw_post.respond_to?(:force_encoding)
        StringIO.new(raw_post)
      else
        @env['rack.input']
      end
    end

    # The raw content type string with its parameters stripped off.
    def content_type_without_parameters
      self.class.extract_content_type_without_parameters(content_type_with_parameters)
    end

    def raw_post
      unless @env.include? 'RAW_POST_DATA'
        @env['RAW_POST_DATA'] = body.read(content_length)
        body.rewind if body.respond_to?(:rewind)
      end
      @env['RAW_POST_DATA']
    end

    private

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
          self.class.parse_multipart_form_parameters(body, boundary, content_length, @env)
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

    def content_length
      @env['CONTENT_LENGTH'].to_i
    end

    # The raw content type string. Use when you need parameters such as
    # charset or boundary which aren't included in the content_type MIME type.
    # Overridden by the X-POST_DATA_FORMAT header for backward compatibility.
    def content_type_with_parameters
      content_type_from_legacy_post_data_format_header || @env['CONTENT_TYPE'].to_s
    end

    def content_type_from_legacy_post_data_format_header
      if x_post_format = @env['HTTP_X_POST_DATA_FORMAT']
        case x_post_format.to_s.downcase
          when 'yaml';  'application/x-yaml'
          when 'xml';   'application/xml'
        end
      end
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
    end # class << self
  end
end
