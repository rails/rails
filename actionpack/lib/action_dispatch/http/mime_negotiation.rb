module ActionDispatch
  module Http
    module MimeNegotiation
      # The MIME type of the HTTP request, such as Mime::XML.
      #
      # For backward compatibility, the post \format is extracted from the
      # X-Post-Data-Format HTTP header if present.
      def content_mime_type
        @env["action_dispatch.request.content_type"] ||= begin
          if @env['CONTENT_TYPE'] =~ /^([^,\;]*)/
            Mime::Type.lookup($1.strip.downcase)
          else
            nil
          end
        end
      end

      def content_type
        content_mime_type && content_mime_type.to_s
      end

      # Returns the accepted MIME type for the request.
      def accepts
        @env["action_dispatch.request.accepts"] ||= begin
          header = @env['HTTP_ACCEPT'].to_s.strip

          if header.empty?
            [content_mime_type]
          else
            Mime::Type.parse(header)
          end
        end
      end

      # Returns the MIME type for the \format used in the request.
      #
      #   GET /posts/5.xml   | request.format => Mime::XML
      #   GET /posts/5.xhtml | request.format => Mime::HTML
      #   GET /posts/5       | request.format => Mime::HTML or MIME::JS, or request.accepts.first
      #
      def format(view_path = [])
        formats.first
      end

      def formats
        accept = @env['HTTP_ACCEPT']

        @env["action_dispatch.request.formats"] ||=
          if parameters[:format]
            Array(Mime[parameters[:format]])
          elsif xhr? || (accept && accept !~ /,\s*\*\/\*/)
            accepts
          else
            [Mime::HTML]
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
        @env["action_dispatch.request.formats"] = [Mime::Type.lookup_by_extension(parameters[:format])]
      end

      # Receives an array of mimes and return the first user sent mime that
      # matches the order array.
      #
      def negotiate_mime(order)
        formats.each do |priority|
          if priority == Mime::ALL
            return order.first
          elsif order.include?(priority)
            return priority
          end
        end

        order.include?(Mime::ALL) ? formats.first : nil
      end
    end
  end
end
