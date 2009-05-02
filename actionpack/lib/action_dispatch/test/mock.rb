module ActionDispatch
  module Test
    class MockRequest < Rack::MockRequest
      MULTIPART_BOUNDARY = "----------XnJLe9ZIbbGUYtzPQJ16u1"

      class << self
        def env_for(path, opts)
          method = (opts[:method] || opts["REQUEST_METHOD"]).to_s.upcase
          opts[:method] = opts["REQUEST_METHOD"] = method

          path = "/#{path}" unless path[0] == ?/
          uri = URI.parse(path)
          uri.host ||= "example.org"

          if URI::HTTPS === uri
            opts.update("SERVER_PORT" => "443", "HTTPS" => "on")
          end

          if method == "POST" && !opts.has_key?(:input)
            opts["CONTENT_TYPE"] = "application/x-www-form-urlencoded"

            multipart = opts[:params].respond_to?(:any?) && opts[:params].any? { |k, v| UploadedFile === v }
            if multipart
              opts[:input] = multipart_body(opts.delete(:params))
              opts["CONTENT_LENGTH"] ||= opts[:input].length.to_s
              opts["CONTENT_TYPE"] = "multipart/form-data; boundary=#{MULTIPART_BOUNDARY}"
            else
              params = opts.delete(:params)
              opts[:input] = case params
                  when Hash then requestify(params)
                  when nil  then ""
                  else params
                end
            end
          end

          params = opts[:params] || {}
          if params.is_a?(String)
            if method == "GET"
              uri.query = params
            else
              opts[:input] = params
            end
          else
            params.stringify_keys!
            params.update(::Rack::Utils.parse_query(uri.query))
            uri.query = requestify(params)
          end

          ::Rack::MockRequest.env_for(uri.to_s, opts)
        end

        private
          def requestify(value, prefix = nil)
            case value
            when Array
              value.map do |v|
                requestify(v, "#{prefix}[]")
              end.join("&")
            when Hash
              value.map do |k, v|
                requestify(v, prefix ? "#{prefix}[#{::Rack::Utils.escape(k)}]" : ::Rack::Utils.escape(k))
              end.join("&")
            else
              "#{prefix}=#{::Rack::Utils.escape(value)}"
            end
          end

          def multipart_requestify(params, first=true)
            p = Hash.new

            params.each do |key, value|
              k = first ? key.to_s : "[#{key}]"

              if Hash === value
                multipart_requestify(value, false).each do |subkey, subvalue|
                  p[k + subkey] = subvalue
                end
              else
                p[k] = value
              end
            end

            return p
          end

          def multipart_body(params)
            multipart_requestify(params).map do |key, value|
              if value.respond_to?(:original_filename)
                ::File.open(value.path, "rb") do |f|
                  f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)

                  <<-EOF
--#{MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{key}"; filename="#{::Rack::Utils.escape(value.original_filename)}"\r
Content-Type: #{value.content_type}\r
Content-Length: #{::File.stat(value.path).size}\r
\r
#{f.read}\r
EOF
            end
          else
<<-EOF
--#{MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{key}"\r
\r
#{value}\r
EOF
              end
            end.join("")+"--#{MULTIPART_BOUNDARY}--\r"
          end
      end
    end
  end
end
