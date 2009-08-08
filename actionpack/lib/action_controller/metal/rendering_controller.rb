module ActionController
  module RenderingController
    extend ActiveSupport::Concern

    include AbstractController::RenderingController

    def process_action(*)
      self.formats = request.formats.map {|x| x.to_sym}
      super
    end

    def render(options)
      super
      self.content_type ||= begin
        mime = options[:_template].mime_type
        formats.include?(mime && mime.to_sym) || formats.include?(:all) ? mime : Mime::Type.lookup_by_extension(formats.first)
      end.to_s
      response_body
    end

    def render_to_body(options)
      _process_options(options)

      if options.key?(:partial)
        options[:partial] = action_name if options[:partial] == true
        options[:_details] = {:formats => formats}
      end

      super
    end

    private
      def _prefix
        controller_path
      end

      def _determine_template(options)
        if options.key?(:text)
          options[:_template] = ActionView::TextTemplate.new(options[:text], formats.first)
        elsif options.key?(:inline)
          handler = ActionView::Template.handler_class_for_extension(options[:type] || "erb")
          template = ActionView::Template.new(options[:inline], "inline #{options[:inline].inspect}", handler, {})
          options[:_template] = template
        elsif options.key?(:template)
          options[:_template_name] = options[:template]
        elsif options.key?(:file)
          options[:_template_name] = options[:file]
        elsif !options.key?(:partial)
          options[:_template_name] = (options[:action] || action_name).to_s
          options[:_prefix] = _prefix
        end

        super
      end

      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)
        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location
      end
  end
end
