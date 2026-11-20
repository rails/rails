# frozen_string_literal: true

module ActionDispatch
  module CoreExt
    module RackMultipartParser # :nodoc:
      def self.apply
        require "rack/multipart"
        Rack::Multipart::Parser.prepend(self)
      end

      if Rack::Multipart::Parser.private_method_defined?(:find_encoding) # Rack 3.1+
        private def find_encoding(...)
          case encoding = super
          when Encoding::UTF_8
            encoding
          when Encoding::US_ASCII
            Encoding::UTF_8 # Might as well tag ASCII as UTF-8 to avoid converstion issues.
          else
            Encoding::BINARY
          end
        end
      else # Older rack versions
        # This patch is less performant and less reliable than the Rack 3.1+ version.
        def tag_multipart_encoding(filename, content_type, name, body)
          super

          return if filename

          if name.is_a?(String) && !name.frozen?
            case name.encoding
            when Encoding::UTF_8, Encoding::BINARY
              # noop
            when Encoding::US_ASCII
              name.force_encoding(Encoding::UTF_8) # Might as well tag ASCII as UTF-8 to avoid converstion issues.
            else
              name.force_encoding(Encoding::BINARY)
            end
          end


          if body.is_a?(String) && !body.frozen?
            case body.encoding
            when Encoding::UTF_8, Encoding::BINARY
              # noop
            when Encoding::US_ASCII
              body.force_encoding(Encoding::UTF_8) # Might as well tag ASCII as UTF-8 to avoid converstion issues.
            else
              body.force_encoding(Encoding::BINARY)
            end
          end
        end

        def get_filename(head)
          filename = super

          if filename.is_a?(String) && !filename.frozen?
            case filename.encoding
            when Encoding::UTF_8, Encoding::BINARY
              # noop
            when Encoding::US_ASCII
              filename.force_encoding(Encoding::UTF_8)
            else
              filename.force_encoding(Encoding::BINARY)
            end
          end

          filename
        end
      end
    end
  end
end
