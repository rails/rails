module ActionController
  module Rendering
    extend ActiveSupport::Concern

    include ActionController::RackDelegation
    include AbstractController::Rendering

    def process(*)
      self.formats = request.formats.map { |x| x.to_sym }
      super
    end

    def render(*args)
      raise ::AbstractController::DoubleRenderError if response_body
      super
      response_body
    end

    private

      def _normalize_args(action=nil, options={}, &blk)
        options = super
        options[:update] = blk if block_given?
        options
      end

      def _normalize_options(options)
        if options.key?(:text) && options[:text].respond_to?(:to_text)
          options[:text] = options[:text].to_text
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        super
      end

      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)

        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location

        super
      end

      def _with_template_hook(template)
        super
        self.content_type ||= template.mime_type.to_s
      end

  end
end
