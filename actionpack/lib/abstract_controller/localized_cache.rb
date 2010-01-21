module AbstractController
  class HashKey
    @hash_keys = Hash.new {|h,k| h[k] = Hash.new {|sh,sk| sh[sk] = {} } }

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
      "#<HashKey -- formats: #{@formats.inspect} locale: #{@locale.inspect}>"
    end
  end

  module LocalizedCache
    extend ActiveSupport::Concern

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

    def render(*args)
      Thread.current[:format_locale_key] = HashKey.get(self.class, formats, I18n.locale)
      super
    end

    private

      def with_template_cache(name)
        self.class.template_cache[Thread.current[:format_locale_key]][name] ||= super
      end

  end
end
