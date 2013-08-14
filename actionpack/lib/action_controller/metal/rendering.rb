module ActionController
  # Basic rendering implements the most minimal rendering layer.
  # It only supports rendering :text and :nothing. Passing any other option will
  # result in `UnsupportedOperationError` exception. For more functionality like
  # different formats, layouts etc. you should use `ActionView` gem.
  module BasicRendering
    extend ActiveSupport::Concern

    # Render template to response_body
    # :api: public
    def render(*args, &block)
      super(*args, &block)
      opts = args.first
      if opts.has_key?(:text) && opts[:text].present?
        self.response_body = opts[:text]
      elsif opts.has_key?(:nothing) && opts[:nothing]
        self.response_body = " "
      else
        raise UnsupportedOperationError
      end
    end

    def rendered_format
      Mime::TEXT
    end

    class UnsupportedOperationError < StandardError
      def initialize
        super "Unsupported render operation. BasicRendering supports only :text
        and :nothing options. For more, you need to include ActionView."
      end
    end
  end

  module Rendering
    extend ActiveSupport::Concern

    # Before processing, set the request formats in current controller formats.
    def process_action(*) #:nodoc:
      self.formats = request.formats.map(&:ref).compact
      super
    end

    # Check for double render errors and set the content_type after rendering.
    def render(*args) #:nodoc:
      raise ::AbstractController::DoubleRenderError if self.response_body
      super
      self.content_type ||= rendered_format.to_s
      self.response_body
    end

    # Overwrite render_to_string because body can now be set to a rack body.
    def render_to_string(*)
      if self.response_body = super
        string = ""
        self.response_body.each { |r| string << r }
        string
      end
    ensure
      self.response_body = nil
    end

    def render_to_body(*)
      super || " "
    end

    private

    # Normalize arguments by catching blocks and setting them on :update.
    def _normalize_args(action=nil, options={}, &blk) #:nodoc:
      options = super
      options[:update] = blk if block_given?
      options
    end

    # Normalize both text and status options.
    def _normalize_options(options) #:nodoc:
      if options.key?(:text) && options[:text].respond_to?(:to_text)
        options[:text] = options[:text].to_text
      end

      if options.delete(:nothing) || (options.key?(:text) && options[:text].nil?)
        options[:text] = " "
      end

      if options[:status]
        options[:status] = Rack::Utils.status_code(options[:status])
      end

      super
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
