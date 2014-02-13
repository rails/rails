require 'active_support/core_ext/module/attribute_accessors'

module ActionDispatch
  module Http
    module MimeNegotiation
      extend ActiveSupport::Concern

      included do
        mattr_accessor :ignore_accept_header
        self.ignore_accept_header = false
      end

      attr_reader :variant

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
        formats.first || Mime::NullType.instance
      end

      def formats
        @env["action_dispatch.request.formats"] ||=
          if parameters[:format]
            Array(Mime[parameters[:format]])
          elsif use_accept_header && valid_accept_header
            accepts
          elsif xhr?
            [Mime::JS]
          else
            [Mime::HTML]
          end
      end

      # Sets the \variant for template.
      def variant=(variant)
        if variant.is_a?(Symbol)
          @variant = [variant]
        elsif variant.is_a?(Array) && variant.any? && variant.all?{ |v| v.is_a?(Symbol) }
          @variant = variant
        else
          raise ArgumentError, "request.variant must be set to a Symbol or an Array of Symbols, not a #{variant.class}. " \
            "For security reasons, never directly set the variant to a user-provided value, " \
            "like params[:variant].to_sym. Check user-provided value against a whitelist first, " \
            "then set the variant: request.variant = :tablet if params[:variant] == 'tablet'"
        end
      end

      # Sets the \format by string extension, which can be used to force custom formats
      # that are not controlled by the extension.
      #
      #   class ApplicationController < ActionController::Base
      #     before_action :adjust_format_for_iphone
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

      # Sets the \formats by string extensions. This differs from #format= by allowing you
      # to set multiple, ordered formats, which is useful when you want to have a fallback.
      #
      # In this example, the :iphone format will be used if it's available, otherwise it'll fallback
      # to the :html format.
      #
      #   class ApplicationController < ActionController::Base
      #     before_action :adjust_format_for_iphone_with_html_fallback
      #
      #     private
      #       def adjust_format_for_iphone_with_html_fallback
      #         request.formats = [ :iphone, :html ] if request.env["HTTP_USER_AGENT"][/iPhone/]
      #       end
      #   end
      def formats=(extensions)
        parameters[:format] = extensions.first.to_s
        @env["action_dispatch.request.formats"] = extensions.collect do |extension|
          Mime::Type.lookup_by_extension(extension)
        end
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

      protected

      BROWSER_LIKE_ACCEPTS = /,\s*\*\/\*|\*\/\*\s*,/

      def valid_accept_header
        (xhr? && (accept.present? || content_mime_type)) ||
          (accept.present? && accept !~ BROWSER_LIKE_ACCEPTS)
      end

      def use_accept_header
        !self.class.ignore_accept_header
      end
    end
  end
end
