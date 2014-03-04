require 'thread_safe'
require 'action_view/dependency_tracker'
require 'monitor'

module ActionView
  class Digestor
    cattr_reader(:cache)
    @@cache          = ThreadSafe::Cache.new
    @@digest_monitor = Monitor.new

    class << self
      # Supported options:
      #
      # * <tt>name</tt>   - Template name
      # * <tt>format</tt>  - Template format
      # * <tt>variant</tt>  - Variant of +format+ (optional)
      # * <tt>finder</tt>  - An instance of ActionView::LookupContext
      # * <tt>dependencies</tt>  - An array of dependent views
      # * <tt>partial</tt>  - Specifies whether the template is a partial
      def digest(*args)
        options = _setup_options(*args)

        name = options[:name]
        format = options[:format]
        variant = options[:variant]
        finder = options[:finder]

        details_key = finder.details_key.hash
        dependencies = Array.wrap(options[:dependencies])
        cache_key = ([name, details_key, format, variant].compact + dependencies).join('.')

        # this is a correctly done double-checked locking idiom
        # (ThreadSafe::Cache's lookups have volatile semantics)
        @@cache[cache_key] || @@digest_monitor.synchronize do
          @@cache.fetch(cache_key) do # re-check under lock
            compute_and_store_digest(cache_key, options)
          end
        end
      end

      def _setup_options(*args)
        unless args.first.is_a?(Hash)
          ActiveSupport::Deprecation.warn("Arguments to ActionView::Digestor should be provided as a hash. The support for regular arguments will be removed in Rails 5.0 or later")

          {
            name:   args.first,
            format: args.second,
            finder: args.third,
          }.merge(args.fourth || {})
        else
          options = args.first
          options.assert_valid_keys(:name, :format, :variant, :finder, :dependencies, :partial)

          options
        end
      end

      private

      def compute_and_store_digest(cache_key, options) # called under @@digest_monitor lock
        klass = if options[:partial] || options[:name].include?("/_")
          # Prevent re-entry or else recursive templates will blow the stack.
          # There is no need to worry about other threads seeing the +false+ value,
          # as they will then have to wait for this thread to let go of the @@digest_monitor lock.
          pre_stored = @@cache.put_if_absent(cache_key, false).nil? # put_if_absent returns nil on insertion
          PartialDigestor
        else
          Digestor
        end

        digest = klass.new(options).digest
        # Store the actual digest if config.cache_template_loading is true
        @@cache[cache_key] = stored_digest = digest if ActionView::Resolver.caching?
        digest
      ensure
        # something went wrong or ActionView::Resolver.caching? is false, make sure not to corrupt the @@cache
        @@cache.delete_pair(cache_key, false) if pre_stored && !stored_digest
      end
    end

    attr_reader :name, :format, :variant, :finder, :options

    def initialize(*args)
      @options = self.class._setup_options(*args)

      @name = @options.delete(:name)
      @format = @options.delete(:format)
      @variant = @options.delete(:variant)
      @finder = @options.delete(:finder)
    end

    def digest
      Digest::MD5.hexdigest("#{source}-#{dependency_digest}").tap do |digest|
        logger.try :info, "Cache digest for #{name}.#{format}: #{digest}"
      end
    rescue ActionView::MissingTemplate
      logger.try :error, "Couldn't find template for digesting: #{name}.#{format}"
      ''
    end

    def dependencies
      DependencyTracker.find_dependencies(name, template)
    rescue ActionView::MissingTemplate
      [] # File doesn't exist, so no dependencies
    end

    def nested_dependencies
      dependencies.collect do |dependency|
        dependencies = PartialDigestor.new(name: dependency, format: format, finder: finder).nested_dependencies
        dependencies.any? ? { dependency => dependencies } : dependency
      end
    end

    private

      def logger
        ActionView::Base.logger
      end

      def logical_name
        name.gsub(%r|/_|, "/")
      end

      def partial?
        false
      end

      def template
        @template ||= finder.find(logical_name, [], partial?, formats: [ format ], variants: [ variant ])
      end

      def source
        template.source
      end

      def dependency_digest
        template_digests = dependencies.collect do |template_name|
          Digestor.digest(name: template_name, format: format, finder: finder, partial: true)
        end

        (template_digests + injected_dependencies).join("-")
      end

      def injected_dependencies
        Array.wrap(options[:dependencies])
      end
  end

  class PartialDigestor < Digestor # :nodoc:
    def partial?
      true
    end
  end
end
