# frozen_string_literal: true

require 'concurrent/map'
require 'active_support/core_ext/module/attribute_accessors'
require 'action_view/template/resolver'

module ActionView
  # = Action View Lookup Context
  #
  # <tt>LookupContext</tt> is the object responsible for holding all information
  # required for looking up templates, i.e. view paths and details.
  # <tt>LookupContext</tt> is also responsible for generating a key, given to
  # view paths, used in the resolver cache lookup. Since this key is generated
  # only once during the request, it speeds up all cache accesses.
  class LookupContext #:nodoc:
    attr_accessor :prefixes, :rendered_format
    deprecate :rendered_format
    deprecate :rendered_format=

    mattr_accessor :fallbacks, default: FallbackFileSystemResolver.instances

    mattr_accessor :registered_details, default: []

    def self.register_detail(name, &block)
      registered_details << name
      Accessors::DEFAULT_PROCS[name] = block

      Accessors.define_method(:"default_#{name}", &block)
      Accessors.module_eval <<-METHOD, __FILE__, __LINE__ + 1
        def #{name}
          @details[:#{name}] || []
        end

        def #{name}=(value)
          value = value.present? ? Array(value) : default_#{name}
          _set_detail(:#{name}, value) if value != @details[:#{name}]
        end
      METHOD
    end

    # Holds accessors for the registered details.
    module Accessors #:nodoc:
      DEFAULT_PROCS = {}
    end

    register_detail(:locale) do
      locales = [I18n.locale]
      locales.concat(I18n.fallbacks[I18n.locale]) if I18n.respond_to? :fallbacks
      locales << I18n.default_locale
      locales.uniq!
      locales
    end
    register_detail(:formats) { ActionView::Base.default_formats || [:html, :text, :js, :css,  :xml, :json] }
    register_detail(:variants) { [] }
    register_detail(:handlers) { Template::Handlers.extensions }

    class DetailsKey #:nodoc:
      alias :eql? :equal?

      @details_keys = Concurrent::Map.new
      @digest_cache = Concurrent::Map.new
      @view_context_mutex = Mutex.new

      def self.digest_cache(details)
        @digest_cache[details_cache_key(details)] ||= Concurrent::Map.new
      end

      def self.details_cache_key(details)
        if details[:formats]
          details = details.dup
          details[:formats] &= Template::Types.symbols
        end
        @details_keys[details] ||= Object.new
      end

      def self.clear
        ActionView::ViewPaths.all_view_paths.each do |path_set|
          path_set.each(&:clear_cache)
        end
        ActionView::LookupContext.fallbacks.each(&:clear_cache)
        @view_context_class = nil
        @details_keys.clear
        @digest_cache.clear
      end

      def self.digest_caches
        @digest_cache.values
      end

      def self.view_context_class(klass)
        @view_context_mutex.synchronize do
          @view_context_class ||= klass.with_empty_template_cache
        end
      end
    end

    # Add caching behavior on top of Details.
    module DetailsCache
      attr_accessor :cache

      # Calculate the details key. Remove the handlers from calculation to improve performance
      # since the user cannot modify it explicitly.
      def details_key #:nodoc:
        @details_key ||= DetailsKey.details_cache_key(@details) if @cache
      end

      # Temporary skip passing the details_key forward.
      def disable_cache
        old_value, @cache = @cache, false
        yield
      ensure
        @cache = old_value
      end

    private
      def _set_detail(key, value) # :doc:
        @details = @details.dup if @digest_cache || @details_key
        @digest_cache = nil
        @details_key = nil
        @details[key] = value
      end
    end

    # Helpers related to template lookup using the lookup context information.
    module ViewPaths
      attr_reader :view_paths, :html_fallback_for_js

      def find(name, prefixes = [], partial = false, keys = [], options = {})
        @view_paths.find(*args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias :find_template :find

      alias :find_file :find
      deprecate :find_file

      def find_all(name, prefixes = [], partial = false, keys = [], options = {})
        @view_paths.find_all(*args_for_lookup(name, prefixes, partial, keys, options))
      end

      def exists?(name, prefixes = [], partial = false, keys = [], **options)
        @view_paths.exists?(*args_for_lookup(name, prefixes, partial, keys, options))
      end
      alias :template_exists? :exists?

      def any?(name, prefixes = [], partial = false)
        @view_paths.exists?(*args_for_any(name, prefixes, partial))
      end
      alias :any_templates? :any?

      # Adds fallbacks to the view paths. Useful in cases when you are rendering
      # a :file.
      def with_fallbacks
        view_paths = build_view_paths((@view_paths.paths + self.class.fallbacks).uniq)

        if block_given?
          ActiveSupport::Deprecation.warn <<~eowarn.squish
          Calling `with_fallbacks` with a block is deprecated.  Call methods on
          the lookup context returned by `with_fallbacks` instead.
          eowarn

          begin
            _view_paths = @view_paths
            @view_paths = view_paths
            yield
          ensure
            @view_paths = _view_paths
          end
        else
          ActionView::LookupContext.new(view_paths, @details, @prefixes)
        end
      end

    private
      # Whenever setting view paths, makes a copy so that we can manipulate them in
      # instance objects as we wish.
      def build_view_paths(paths)
        ActionView::PathSet.new(Array(paths))
      end

      def args_for_lookup(name, prefixes, partial, keys, details_options)
        name, prefixes = normalize_name(name, prefixes)
        details, details_key = detail_args_for(details_options)
        [name, prefixes, partial || false, details, details_key, keys]
      end

      # Compute details hash and key according to user options (e.g. passed from #render).
      def detail_args_for(options) # :doc:
        return @details, details_key if options.empty? # most common path.
        user_details = @details.merge(options)

        if @cache
          details_key = DetailsKey.details_cache_key(user_details)
        else
          details_key = nil
        end

        [user_details, details_key]
      end

      def args_for_any(name, prefixes, partial)
        name, prefixes = normalize_name(name, prefixes)
        details, details_key = detail_args_for_any
        [name, prefixes, partial || false, details, details_key]
      end

      def detail_args_for_any
        @detail_args_for_any ||= begin
          details = {}

          registered_details.each do |k|
            if k == :variants
              details[k] = :any
            else
              details[k] = Accessors::DEFAULT_PROCS[k].call
            end
          end

          if @cache
            [details, DetailsKey.details_cache_key(details)]
          else
            [details, nil]
          end
        end
      end

      # Support legacy foo.erb names even though we now ignore .erb
      # as well as incorrectly putting part of the path in the template
      # name instead of the prefix.
      def normalize_name(name, prefixes)
        prefixes = prefixes.presence
        parts    = name.to_s.split('/')
        parts.shift if parts.first.empty?
        name = parts.pop

        return name, prefixes || [''] if parts.empty?

        parts    = parts.join('/')
        prefixes = prefixes ? prefixes.map { |p| "#{p}/#{parts}" } : [parts]

        return name, prefixes
      end
    end

    include Accessors
    include DetailsCache
    include ViewPaths

    def initialize(view_paths, details = {}, prefixes = [])
      @details_key = nil
      @digest_cache = nil
      @cache = true
      @prefixes = prefixes

      @details = initialize_details({}, details)
      @view_paths = build_view_paths(view_paths)
    end

    def digest_cache
      @digest_cache ||= DetailsKey.digest_cache(@details)
    end

    def with_prepended_formats(formats)
      details = @details.dup
      details[:formats] = formats

      self.class.new(@view_paths, details, @prefixes)
    end

    def initialize_details(target, details)
      registered_details.each do |k|
        target[k] = details[k] || Accessors::DEFAULT_PROCS[k].call
      end
      target
    end
    private :initialize_details

    # Override formats= to expand ["*/*"] values and automatically
    # add :html as fallback to :js.
    def formats=(values)
      if values
        values = values.dup
        values.concat(default_formats) if values.delete '*/*'
        values.uniq!

        invalid_values = (values - Template::Types.symbols)
        unless invalid_values.empty?
          raise ArgumentError, "Invalid formats: #{invalid_values.map(&:inspect).join(", ")}"
        end

        if values == [:js]
          values << :html
          @html_fallback_for_js = true
        end
      end
      super(values)
    end

    # Override locale to return a symbol instead of array.
    def locale
      @details[:locale].first
    end

    # Overload locale= to also set the I18n.locale. If the current I18n.config object responds
    # to original_config, it means that it has a copy of the original I18n configuration and it's
    # acting as proxy, which we need to skip.
    def locale=(value)
      if value
        config = I18n.config.respond_to?(:original_config) ? I18n.config.original_config : I18n.config
        config.locale = value
      end

      super(default_locale)
    end
  end
end
