# frozen_string_literal: true

require "concurrent/map"
require "active_support/core_ext/module/attribute_accessors"
require "action_view/template/resolver"

module ActionView
  # = Action View Lookup Context
  #
  # <tt>LookupContext</tt> is the object responsible for holding all information
  # required for looking up templates, i.e. view paths and details.
  # <tt>LookupContext</tt> is also responsible for generating a key, given to
  # view paths, used in the resolver cache lookup. Since this key is generated
  # only once during the request, it speeds up all cache accesses.
  class LookupContext # :nodoc:
    attr_accessor :prefixes

    def self.clear
      ActionView::PathRegistry.all_resolvers.each(&:clear_cache)
      reset_view_context_class
      Digestor.clear_cache
    end

    class Details
      def initialize(locale: nil, formats: nil, variants: nil, handlers: nil)
        @locale   = locale   && Array(locale)
        @formats  = formats  && Array(formats)
        @variants = variants == :any ? :any : variants && Array(variants)
        @handlers = handlers && Array(handlers)
      end

      attr_reader :html_fallback_for_js

      def locale
        @locale ||= default_locale
      end

      def locale=(value)
        value = value.present? ? Array(value) : default_locale
        return if value == @locale
        @locale = value
        @digest_cache = nil
      end

      def formats
        @formats ||= default_formats
      end

      def formats=(values)
        if values
          values = values.dup
          values.concat(default_formats) if values.delete "*/*"
          values.uniq!

          Template.validate_formats(values)

          if (values.length == 1) && (values[0] == :js)
            values << :html
            @html_fallback_for_js = true
          end
        end

        values = values.presence || default_formats
        return if values == @formats
        @formats = values
        @digest_cache = nil
      end

      def variants
        @variants ||= default_variants
      end

      def variants=(value)
        value = value.present? ? Array(value) : default_variants
        return if value == @variants
        @variants = value
        @digest_cache = nil
      end

      def handlers
        @handlers ||= default_handlers
      end

      def handlers=(value)
        value = value.present? ? Array(value) : default_handlers
        return if value == @handlers
        @handlers = value
        @digest_cache = nil
      end

      def default_locale
        locales = [I18n.locale]
        locales.concat(I18n.fallbacks[I18n.locale]) if I18n.respond_to? :fallbacks
        locales << I18n.default_locale
        locales.uniq!
        locales
      end

      def default_formats
        ActionView::Base.default_formats || [:html, :text, :js, :css, :xml, :json]
      end

      def default_variants
        []
      end

      def default_handlers
        Template::Handlers.extensions
      end

      def digest_cache
        @digest_cache ||= Digestor.cache(to_cache_key)
      end

      def merge(options)
        return self if [:locale, :formats, :variants, :handlers].freeze.none? { |key| options[key] }
        self.class.new(
          locale:   options[:locale]   || locale,
          formats:  options[:formats]  || formats,
          variants: options[:variants] || variants,
          handlers: options[:handlers] || handlers,
        )
      end

      def template_rank(template)
        d = template.details
        format  = rank(formats, d.format)     or return
        locale  = rank(self.locale, d.locale) or return
        variant = variant_rank(d.variant)     or return
        handler = rank(handlers, d.handler)   or return
        [format, locale, variant, handler]
      end

      def to_h
        { locale: locale, formats: formats, variants: variants, handlers: handlers }
      end

      private
        def initialize_copy(other)
          @digest_cache = nil
          super
        end

        def rank(requested, value)
          if requested
            requested.index(value) || (requested.size if value.nil?)
          elsif value.nil?
            0
          end
        end

        def variant_rank(value)
          if variants == :any
            value.nil? ? 0 : 1
          else
            rank(variants, value)
          end
        end

        def to_cache_key
          [locale, Template.normalized_formats(formats) || formats, variants, handlers].freeze
        end
    end

    def self.reset_view_context_class
      @view_context_mutex.synchronize { @view_context_class = nil }
    end

    def self.view_context_class
      return @view_context_class if @view_context_class
      base = ActionView::Base # prevent recursive locking
      @view_context_mutex.synchronize do
        @view_context_class = base.with_empty_template_cache
      end
    end
    @view_context_mutex = Mutex.new
    ActiveSupport.on_load(:action_view) { ActionView::LookupContext.view_context_class }

    # Helpers related to template lookup using the lookup context information.
    module ViewPaths
      attr_reader :view_paths

      def find(name, prefixes = [], partial = false, keys = [], options = nil)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.find(name, prefixes, partial, details_for(options), @cache, keys)
      end

      def find!(name, prefixes = [], partial = false, keys = [], options = nil)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.find!(name, prefixes, partial, details_for(options), @cache, keys)
      end

      def find_all(name, prefixes = [], partial = false, keys = [], options = nil)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.find_all(name, prefixes, partial, details_for(options), @cache, keys)
      end

      def exists?(name, prefixes = [], partial = false, keys = [], **options)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.exists?(name, prefixes, partial, details_for(options), @cache, keys)
      end
      alias :template_exists? :exists?

      def any?(name, prefixes = [], partial = false)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.exists?(name, prefixes, partial, details_for_any, @cache, [])
      end
      alias :any_templates? :any?

      def any_formats?(name, prefixes = [], partial = false, keys = [], options = nil)
        name, prefixes = normalize_name(name, prefixes)
        @view_paths.exists?(name, prefixes, partial, details_for(options).merge(formats: default_formats), @cache, keys)
      end

      def append_view_paths(paths)
        @view_paths = build_view_paths(@view_paths.to_a + paths)
      end

      def prepend_view_paths(paths)
        @view_paths = build_view_paths(paths + @view_paths.to_a)
      end

      # Resolves the Details to look up with from the user options passed to
      # #render (e.g. <tt>formats: :json</tt>): the context's own Details when
      # there are none, an already-resolved Details (e.g. from a renderer) left
      # untouched, or the context's Details with the overrides layered on.
      def details_for(options)
        return @details unless options
        return options if Details === options
        @details.merge(options)
      end

    private
      # Whenever setting view paths, makes a copy so that we can manipulate them in
      # instance objects as we wish.
      def build_view_paths(paths)
        if ActionView::PathSet === paths
          paths
        else
          ActionView::PathSet.new(Array(paths))
        end
      end

      def details_for_any
        @details_for_any ||= Details.new(variants: :any)
      end

      # Fix when prefix is specified as part of the template name
      def normalize_name(name, prefixes)
        name = name.to_s
        idx = name.rindex("/")
        return name, prefixes.presence || [""] unless idx

        path_prefix = name[0, idx]
        path_prefix = path_prefix.from(1) if path_prefix.start_with?("/")
        name = name.from(idx + 1)

        if !prefixes || prefixes.empty?
          prefixes = [path_prefix]
        else
          prefixes = prefixes.map { |p| "#{p}/#{path_prefix}" }
        end

        return name, prefixes
      end
    end

    include ViewPaths

    attr_accessor :cache

    def initialize(view_paths, details = {}, prefixes = [])
      @cache = true
      @prefixes = prefixes

      @details = if details.is_a?(Details)
        details
      else
        Details.new(
          locale:   details[:locale],
          formats:  details[:formats],
          variants: details[:variants],
          handlers: details[:handlers],
        )
      end

      @view_paths = build_view_paths(view_paths)
    end

    delegate :formats, :formats=, :variants, :variants=, :handlers, :handlers=,
             :html_fallback_for_js, :default_formats, :digest_cache, to: :@details

    def disable_cache
      old_value, @cache = @cache, false
      yield
    ensure
      @cache = old_value
    end

    def with_prepended_formats(formats)
      details = @details.dup
      details.formats = formats

      self.class.new(@view_paths, details, @prefixes)
    end

    # Override locale to return a symbol instead of array.
    def locale
      @details.locale.first
    end

    # Overload locale= to also set the I18n.locale. If the current I18n.config object responds
    # to original_config, it means that it has a copy of the original I18n configuration and it's
    # acting as proxy, which we need to skip.
    def locale=(value)
      if value
        config = I18n.config.respond_to?(:original_config) ? I18n.config.original_config : I18n.config
        config.locale = value
      end

      @details.locale = @details.default_locale
    end
  end
end
