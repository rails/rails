module AbstractController
  class HashKey
    @hash_keys = Hash.new {|h,k| h[k] = {} }

    def self.get(klass, details)
      @hash_keys[klass][details] ||= new(klass, details)
    end

    attr_reader :hash
    alias_method :eql?, :equal?

    def initialize(klass, details)
      @details, @hash = details, details.hash
    end

    def inspect
      "#<HashKey -- details: #{@details.inspect}>"
    end
  end

  module DetailsCache
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

    def render_to_body(*args)
      Thread.current[:format_locale_key] = HashKey.get(self.class, details_for_render)
      super
    end

    private

      def with_template_cache(name, details)
        self.class.template_cache[HashKey.get(self.class, details)][name] ||= super
      end

  end
end
