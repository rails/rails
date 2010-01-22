module ActionController
  module Rendering
    extend ActiveSupport::Concern

    included do
      include AbstractController::Rendering
      include AbstractController::LocalizedCache
    end

    def process_action(*)
      self.formats = request.formats.map {|x| x.to_sym}
      super
    end

    def render(*args)
      args << {} unless args.last.is_a?(Hash)
      super(*args)
      self.content_type ||= args.last[:_template].mime_type.to_s
      response_body
    end

    def render_to_body(options)
      _process_options(options)
      super
    end

    private

      def _render_partial(options)
        options[:partial] = action_name if options[:partial] == true
        options[:_details] = {:formats => formats}
        super
      end

      def format_for_text
        formats.first
      end

      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)
        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location
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

        if (options.keys & [:partial, :file, :template, :text, :inline]).empty?
          options[:_template_name] ||= options[:action]
          options[:_prefix] = _prefix
        end

        if options[:status]
          options[:status] = Rack::Utils.status_code(options[:status])
        end

        options[:update] = blk if block_given?
        options
      end
  end
end
