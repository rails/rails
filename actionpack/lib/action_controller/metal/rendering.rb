require "active_support/core_ext/string/filters"

module ActionController
  module Rendering
    extend ActiveSupport::Concern

    RENDER_FORMATS_IN_PRIORITY = [:body, :text, :plain, :html]

    module ClassMethods
      # Documentation at ActionController::Renderer#render
      delegate :render, to: :renderer

      # Returns a renderer instance (inherited from ActionController::Renderer)
      # for the controller.
      attr_reader :renderer

      def setup_renderer! # :nodoc:
        @renderer = Renderer.for(self)
      end

      def inherited(klass)
        klass.setup_renderer!
        super
      end
    end

    # Before processing, set the request formats in current controller formats.
    def process_action(*) #:nodoc:
      self.formats = request.formats.map(&:ref).compact
      super
    end

    # Check for double render errors and set the content_type after rendering.
    def render(*args) #:nodoc:
      raise ::AbstractController::DoubleRenderError if response_body
      super
    end

    # Overwrite render_to_string because body can now be set to a rack body.
    def render_to_string(*)
      result = super
      if result.respond_to?(:each)
        string = ""
        result.each { |r| string << r }
        string
      else
        result
      end
    end

    def render_to_body(options = {})
      super || _render_in_priorities(options) || " "
    end

    private

      def _render_in_priorities(options)
        RENDER_FORMATS_IN_PRIORITY.each do |format|
          return options[format] if options.key?(format)
        end

        nil
      end

      def _set_html_content_type
        self.content_type = Mime[:html].to_s
      end

      def _set_rendered_content_type(format)
        unless response.content_type
          self.content_type = format.to_s
        end
      end

    # Normalize arguments by catching blocks and setting them on :update.
      def _normalize_args(action=nil, options={}, &blk) #:nodoc:
        options = super
        options[:update] = blk if block_given?
        options
      end

    # Normalize both text and status options.
      def _normalize_options(options) #:nodoc:
        _normalize_text(options)

        if options[:text]
          ActiveSupport::Deprecation.warn <<-WARNING.squish
          `render :text` is deprecated because it does not actually render a
          `text/plain` response. Switch to `render plain: 'plain text'` to
          render as `text/plain`, `render html: '<strong>HTML</strong>'` to
          render as `text/html`, or `render body: 'raw'` to match the deprecated
          behavior and render with the default Content-Type, which is
          `text/plain`.
        WARNING
        end

        if options[:html]
          options[:html] = ERB::Util.html_escape(options[:html])
        end

        if options.delete(:nothing)
          ActiveSupport::Deprecation.warn("`:nothing` option is deprecated and will be removed in Rails 5.1. Use `head` method to respond with empty response body.")
          options[:body] = nil
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        super
      end

      def _normalize_text(options)
        RENDER_FORMATS_IN_PRIORITY.each do |format|
          if options.key?(format) && options[format].respond_to?(:to_text)
            options[format] = options[format].to_text
          end
        end
      end

    # Process controller specific options, as status, content-type and location.
      def _process_options(options) #:nodoc:
        status, content_type, location = options.values_at(:status, :content_type, :location)

        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location

        super
      end
  end
end
