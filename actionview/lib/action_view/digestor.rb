require 'concurrent/map'
require 'action_view/dependency_tracker'
require 'monitor'

module ActionView
  class Digestor
    @@digest_monitor = Monitor.new

    class PerRequestDigestCacheExpiry < Struct.new(:app) # :nodoc:
      def call(env)
        ActionView::LookupContext::DetailsKey.clear
        app.call(env)
      end
    end

    class << self
      # Supported options:
      #
      # * <tt>name</tt>   - Template name
      # * <tt>finder</tt>  - An instance of <tt>ActionView::LookupContext</tt>
      # * <tt>dependencies</tt>  - An array of dependent views
      # * <tt>partial</tt>  - Specifies whether the template is a partial
      def digest(name:, finder:, **options)
        options.assert_valid_keys(:dependencies, :partial)

        cache_key = ([ name ].compact + Array.wrap(options[:dependencies])).join('.')

        # this is a correctly done double-checked locking idiom
        # (Concurrent::Map's lookups have volatile semantics)
        finder.digest_cache[cache_key] || @@digest_monitor.synchronize do
          finder.digest_cache.fetch(cache_key) do # re-check under lock
            compute_and_store_digest(cache_key, name, finder, options)
          end
        end
      end

      private
        def compute_and_store_digest(cache_key, name, finder, options) # called under @@digest_monitor lock
          klass = if options[:partial] || name.include?("/_")
            # Prevent re-entry or else recursive templates will blow the stack.
            # There is no need to worry about other threads seeing the +false+ value,
            # as they will then have to wait for this thread to let go of the @@digest_monitor lock.
            pre_stored = finder.digest_cache.put_if_absent(cache_key, false).nil? # put_if_absent returns nil on insertion
            PartialDigestor
          else
            Digestor
          end

          finder.digest_cache[cache_key] = stored_digest = klass.new(name, finder, options).digest
        ensure
          # something went wrong or ActionView::Resolver.caching? is false, make sure not to corrupt the @@cache
          finder.digest_cache.delete_pair(cache_key, false) if pre_stored && !stored_digest
        end
    end

    attr_reader :name, :finder, :options

    def initialize(name, finder, options = {})
      @name, @finder = name, finder
      @options = options
    end

    def digest
      Digest::MD5.hexdigest("#{source}-#{dependency_digest}").tap do |digest|
        logger.debug "  Cache digest for #{template.inspect}: #{digest}"
      end
    rescue ActionView::MissingTemplate
      logger.error "  Couldn't find template for digesting: #{name}"
      ''
    end

    def dependencies
      DependencyTracker.find_dependencies(name, template, finder.view_paths)
    rescue ActionView::MissingTemplate
      logger.error "  '#{name}' file doesn't exist, so no dependencies"
      []
    end

    def nested_dependencies
      dependencies.collect do |dependency|
        dependencies = PartialDigestor.new(dependency, finder).nested_dependencies
        dependencies.any? ? { dependency => dependencies } : dependency
      end
    end

    private
      class NullLogger
        def self.debug(_); end
        def self.error(_); end
      end

      def logger
        ActionView::Base.logger || NullLogger
      end

      def logical_name
        name.gsub(%r|/_|, "/")
      end

      def partial?
        false
      end

      def template
        @template ||= finder.disable_cache { finder.find(logical_name, [], partial?) }
      end

      def source
        template.source
      end

      def dependency_digest
        template_digests = dependencies.collect do |template_name|
          Digestor.digest(name: template_name, finder: finder, partial: true)
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
