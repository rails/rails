require 'concurrent/map'
require 'action_view/dependency_tracker'
require 'monitor'

module ActionView
  class Digestor
    cattr_reader(:cache)
    @@cache          = Concurrent::Map.new
    @@digest_monitor = Monitor.new

    class PerRequestDigestCacheExpiry < Struct.new(:app) # :nodoc:
      def call(env)
        ActionView::Digestor.cache.clear
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

        cache_key = ([ name, finder.details_key.hash ].compact + Array.wrap(options[:dependencies])).join('.')

        # this is a correctly done double-checked locking idiom
        # (Concurrent::Map's lookups have volatile semantics)
        @@cache[cache_key] || @@digest_monitor.synchronize do
          @@cache.fetch(cache_key) do # re-check under lock
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
            pre_stored = @@cache.put_if_absent(cache_key, false).nil? # put_if_absent returns nil on insertion
            PartialDigestor
          else
            Digestor
          end

          @@cache[cache_key] = stored_digest = klass.new(name, finder, options).digest
        ensure
          # something went wrong or ActionView::Resolver.caching? is false, make sure not to corrupt the @@cache
          @@cache.delete_pair(cache_key, false) if pre_stored && !stored_digest
        end
    end

    def self.tree(name, finder, injected = [], partial = false, seen = {})
      logical_name = name.gsub(%r|/_|, "/")
      partial = partial || name.include?("/_")

      if finder.disable_cache { finder.exists?(logical_name, [], partial) }
        template = finder.disable_cache { finder.find(logical_name, [], partial) }

        if obj = seen[template.identifier]
          obj
        else
          node = seen[template.identifier] = Node.create(name, logical_name, template, partial)

          deps = DependencyTracker.find_dependencies(name, template, finder.view_paths)
          deps.each do |dep_file|
            node.children << tree(dep_file, finder, [], true, seen)
          end
          injected.each do |template|
            node.children << Injected.new(template, nil, nil)
          end
          node
        end
      else
        seen[name] = Missing.new(name, logical_name, nil)
      end
    end

    class Node < Struct.new(:name, :logical_name, :template, :children)
      def self.class_for(partial)
        partial ? Partial : Node
      end

      def self.create(name, logical_name, template, partial)
        class_for(partial).new(name, logical_name, template, [])
      end

      def initialize(name, logical_name, template, children = [])
        super
      end

      def to_dep(finder)
        Digestor.new(name, finder, partial: true)
      end

      def digest(stack = [])
        Digest::MD5.hexdigest("#{template.source}-#{dependency_digest(stack)}")
      end

      def dependency_digest(stack)
        children.map do |node|
          if stack.include?(node)
            false
          else
            stack.push node
            node.digest(stack).tap { stack.pop }
          end
        end.join("-")
      end
    end

    class Partial < Node
      def to_dep(finder)
        PartialDigestor.new(name, finder, partial: false)
      end
    end

    class Missing < Node
      def digest(_ = [])
        ''
      end
    end

    class Injected < Node
      def digest(_ = [])
        name
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

    def children
      dependencies.collect do |dependency|
        PartialDigestor.new(dependency, finder)
      end
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
