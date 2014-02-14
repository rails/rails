module ActionController
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
      super || options[:body].presence || options[:text].presence || options[:plain].presence || ERB::Util.h(options[:html]).presence || ' '
    end

    private

    def _process_format(format, options = {})
      super
      self.content_type ||= format.to_s

      if options[:body].present?
        self.content_type = "none"
        self.headers.delete "Content-Type"
      end

      if options[:plain].present?
        self.content_type = Mime::TEXT
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
      if options.key?(:body) && options[:body].respond_to?(:to_text)
        options[:body] = options[:body].to_text
      end

      if options.key?(:text) && options[:text].respond_to?(:to_text)
        options[:text] = options[:text].to_text
      end

      if options.key?(:plain) && options[:plain].respond_to?(:to_text)
        options[:plain] = options[:plain].to_text
      end

      if options.delete(:nothing) || (options.key?(:body) && options[:body].nil?) || (options.key?(:text) && options[:text].nil?) || (options.key?(:plain) && options[:plain].nil?) || (options.key?(:html) && options[:html].nil?)
        options[:body] = " "
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
