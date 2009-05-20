module Rack
  module Test

    module Utils
      include Rack::Utils

      def requestify(value, prefix = nil)
        case value
        when Array
          value.map do |v|
            requestify(v, "#{prefix}[]")
          end.join("&")
        when Hash
          value.map do |k, v|
            requestify(v, prefix ? "#{prefix}[#{escape(k)}]" : escape(k))
          end.join("&")
        else
          "#{prefix}=#{escape(value)}"
        end
      end

      module_function :requestify

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

      module_function :multipart_requestify

      def multipart_body(params)
        multipart_requestify(params).map do |key, value|
          if value.respond_to?(:original_filename)
            ::File.open(value.path, "rb") do |f|
              f.set_encoding(Encoding::BINARY) if f.respond_to?(:set_encoding)

              <<-EOF
--#{MULTIPART_BOUNDARY}\r
Content-Disposition: form-data; name="#{key}"; filename="#{escape(value.original_filename)}"\r
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

      module_function :multipart_body

    end

  end
end
