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

      def format_for_text
        formats.first
      end

      def with_template_cache(name)
        self.class.template_cache[Thread.current[:format_locale_key]][name] ||= super
      end

      def _process_options(options)
        status, content_type, location = options.values_at(:status, :content_type, :location)
        self.status = status if status
        self.content_type = content_type if content_type
        self.headers["Location"] = url_for(location) if location
      end
  end
end
