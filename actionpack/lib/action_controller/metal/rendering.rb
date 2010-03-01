module ActionController
  module Rendering
    extend ActiveSupport::Concern

    include ActionController::RackDelegation
    include AbstractController::Rendering
    include AbstractController::DetailsCache

    def process_action(*)
      self.formats = request.formats.map {|x| x.to_sym }
      super
    end

    def render(*args)
      raise ::AbstractController::DoubleRenderError if response_body
      args << {} unless args.last.is_a?(Hash)
      super(*args)
      self.content_type ||= args.last[:_template].mime_type.to_s
      response_body
    end

    private

      def _render_partial(options)
        options[:partial] = action_name if options[:partial] == true
        options[:_details] = details_for_render
        super
      end

      def details_for_render
        {:formats => formats}
      end

      def format_for_text
        formats.first
      end

      def _normalize_options(action=nil, options={}, &blk)
        case action
        when NilClass
        when Hash
          options = super(action.delete(:action), action)
        when String, Symbol
          options = super
        else
          options.merge! :partial => action
        end

        if options.key?(:text) && options[:text].respond_to?(:to_text)
          options[:text] = options[:text].to_text
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        options[:update] = blk if block_given?

        _process_options(options)
        options
      end

      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)
        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location
      end
  end
end
