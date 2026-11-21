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

          _rails_restrict_encoding(name)
          _rails_restrict_encoding(body)
        end

        def get_filename(head)
          _rails_restrict_encoding(super)
        end

        private
          def _rails_restrict_encoding(string)
            if string.is_a?(String) && !string.frozen?
              case string.encoding
              when Encoding::UTF_8, Encoding::BINARY
                # noop
              when Encoding::US_ASCII
                # Might as well tag ASCII as UTF-8 to avoid converstion issues.
                string.force_encoding(Encoding::UTF_8)
              else
                string.force_encoding(Encoding::BINARY)
              end
            end
            string
          end
      end
    end
  end
end
