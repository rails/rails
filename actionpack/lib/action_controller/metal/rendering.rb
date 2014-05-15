module ActionController
  module Rendering
    extend ActiveSupport::Concern

    RENDER_FORMATS_IN_PRIORITY = [:body, :text, :plain, :html]

    # Before processing, set the request formats in current controller formats.
    def process_action(*) #:nodoc:
      self.formats = request.formats.map(&:ref).compact
      super
    end

    # Check for double render errors and set the content_type after rendering.
    def render(*args) #:nodoc:
      raise ::AbstractController::DoubleRenderError if self.response_body
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
      super || _render_in_priorities(options) || ' '
    end

    private

    def _render_in_priorities(options)
      RENDER_FORMATS_IN_PRIORITY.each do |format|
        return options[format] if options.key?(format)
      end

      nil
    end

    def _process_format(format, options = {})
      super

      if options[:plain]
        self.content_type = Mime::TEXT
      else
        self.content_type ||= format.to_s
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

      if options[:html]
        options[:html] = ERB::Util.html_escape(options[:html])
      end

      if options.delete(:nothing) || _any_render_format_is_nil?(options)
        options[:body] = " "
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

    def _any_render_format_is_nil?(options)
      RENDER_FORMATS_IN_PRIORITY.any? { |format| options.key?(format) && options[format].nil? }
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
