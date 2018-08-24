# frozen_string_literal: true

require "active_support/core_ext/module/attribute_accessors"

module ActionDispatch
  module Http
    module MimeNegotiation
      extend ActiveSupport::Concern

      included do
        mattr_accessor :ignore_accept_header, default: false
      end

      # The MIME type of the HTTP request, such as Mime[:xml].
      def content_mime_type
        fetch_header("action_dispatch.request.content_type") do |k|
          v = if get_header("CONTENT_TYPE") =~ /^([^,\;]*)/
            Mime::Type.lookup($1.strip.downcase)
          else
            nil
          end
          set_header k, v
        end
      end

      def content_type
        content_mime_type && content_mime_type.to_s
      end

      def has_content_type? # :nodoc:
        get_header "CONTENT_TYPE"
      end

      # Returns the accepted MIME type for the request.
      def accepts
        fetch_header("action_dispatch.request.accepts") do |k|
          header = get_header("HTTP_ACCEPT").to_s.strip

          v = if header.empty?
            [content_mime_type]
          else
            Mime::Type.parse(header)
          end
          set_header k, v
        end
      end

      # Returns the MIME type for the \format used in the request.
      #
      #   GET /posts/5.xml   | request.format => Mime[:xml]
      #   GET /posts/5.xhtml | request.format => Mime[:html]
      #   GET /posts/5       | request.format => Mime[:html] or Mime[:js], or request.accepts.first
      #
      def format(view_path = [])
        formats.first || Mime::NullType.instance
      end

      def formats
        fetch_header("action_dispatch.request.formats") do |k|
          params_readable = begin
                              parameters[:format]
                            rescue ActionController::BadRequest
                              false
                            end

          v = if params_readable
            Array(Mime[parameters[:format]])
          elsif use_accept_header && valid_accept_header
            accepts
          elsif extension_format = format_from_path_extension
            [extension_format]
          elsif xhr?
            [Mime[:js]]
          else
            [Mime[:html]]
          end
          set_header k, v
        end
      end

      # Sets the \variant for template.
      def variant=(variant)
        variant = Array(variant)

        if variant.all? { |v| v.is_a?(Symbol) }
          @variant = ActiveSupport::ArrayInquirer.new(variant)
        else
          raise ArgumentError, "request.variant must be set to a Symbol or an Array of Symbols. " \
            "For security reasons, never directly set the variant to a user-provided value, " \
            "like params[:variant].to_sym. Check user-provided value against a permitted list first, " \
            "then set the variant: request.variant = :tablet if params[:variant] == 'tablet'"
        end
      end

      def variant
        @variant ||= ActiveSupport::ArrayInquirer.new
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
        set_header "action_dispatch.request.formats", [Mime::Type.lookup_by_extension(parameters[:format])]
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
        set_header "action_dispatch.request.formats", extensions.collect { |extension|
          Mime::Type.lookup_by_extension(extension)
        }
      end

      # Returns the first MIME type that matches the provided array of MIME types.
      def negotiate_mime(order)
        formats.each do |priority|
          if priority == Mime::ALL
            return order.first
          elsif order.include?(priority)
            return priority
          end
        end

        order.include?(Mime::ALL) ? format : nil
      end

      private

        BROWSER_LIKE_ACCEPTS = /,\s*\*\/\*|\*\/\*\s*,/

        def valid_accept_header # :doc:
          (xhr? && (accept.present? || content_mime_type)) ||
            (accept.present? && accept !~ BROWSER_LIKE_ACCEPTS)
        end

        def use_accept_header # :doc:
          !self.class.ignore_accept_header
        end

        def format_from_path_extension # :doc:
          path = get_header("action_dispatch.original_path") || get_header("PATH_INFO")
          if match = path && path.match(/\.(\w+)\z/)
            Mime[match.captures.first]
          end
        end
    end
  end
end
