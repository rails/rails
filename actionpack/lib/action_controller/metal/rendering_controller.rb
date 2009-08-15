module ActionController
  class HashKey
    @hash_keys = Hash.new {|h,k| h[k] = Hash.new {|h,k| h[k] = {} } }

    def self.get(klass, formats, locale)
      @hash_keys[klass][formats][locale] ||= new(klass, formats, locale)
    end

    attr_accessor :hash
    def initialize(klass, formats, locale)
      @formats, @locale = formats, locale
      @hash = [formats, locale].hash
    end

    alias_method :eql?, :equal?

    def inspect
      "#<HashKey -- formats: #{@formats} locale: #{@locale}>"
    end
  end

  module RenderingController
    extend ActiveSupport::Concern

    include AbstractController::RenderingController

    module ClassMethods
      def clear_template_caches!
        ActionView::Partials::PartialRenderer::TEMPLATES.clear
        template_cache.clear
        super
      end

      def template_cache
        @template_cache ||= Hash.new {|h,k| h[k] = {} }
      end
    end

    def process_action(*)
      self.formats = request.formats.map {|x| x.to_sym}

      super
    end

    def _determine_template(*)
      super
    end

    def render(options)
      Thread.current[:format_locale_key] = HashKey.get(self.class, formats, I18n.locale)

      super
      self.content_type ||= options[:_template].mime_type.to_s
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

      def with_template_cache(name)
        self.class.template_cache[Thread.current[:format_locale_key]][name] ||= super
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
