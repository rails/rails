module ActionDispatch
  module Routing
    class Scope
      def root(options = {})
        match '/', { :as => :root, :via => :get }.merge!(options)
      end

      def match(path, *rest)
        if rest.empty? && Hash === path
          options  = path
          path, to = options.find { |name, _value| name.is_a?(String) }

          case to
          when Symbol
            options[:action] = to
          when String
            if to =~ /#/
              options[:to] = to
            else
              options[:controller] = to
            end
          else
            options[:to] = to
          end

          options.delete(path)
          paths = [path]
        else
          options = rest.pop || {}
          paths = [path] + rest
        end

        options[:anchor] = true unless options.key?(:anchor)

        if options[:on] && !VALID_ON_OPTIONS.include?(options[:on])
          raise ArgumentError, "Unknown scope #{on.inspect} given to :on"
        end

        if @scope[:controller] && @scope[:action]
          options[:to] ||= "#{@scope[:controller]}##{@scope[:action]}"
        end

        paths.each do |_path|
          route_options = options.dup
          route_options[:path] ||= _path if _path.is_a?(String)

          path_without_format = _path.to_s.sub(/\(\.:format\)$/, '')
          if using_match_shorthand?(path_without_format, route_options)
            route_options[:to] ||= path_without_format.gsub(%r{^/}, "").sub(%r{/([^/]*)$}, '#\1')
            route_options[:to].tr!("-", "_")
          end

          decomposed_match(_path, route_options)
        end
        self
      end

      def get(*args, &block)
        map_method(:get, args, &block)
      end

      def post(*args, &block)
        map_method(:post, args, &block)
      end

      def patch(*args, &block)
        map_method(:patch, args, &block)
      end

      def put(*args, &block)
        map_method(:put, args, &block)
      end

      def delete(*args, &block)
        map_method(:delete, args, &block)
      end

      def mount(app, options = nil)
        if options
          path = options.delete(:at)
        else
          unless Hash === app
            raise ArgumentError, "must be called with mount point"
          end

          options = app
          app, path = options.find { |k, _| k.respond_to?(:call) }
          options.delete(app) if app
        end

        raise "A rack application must be specified" unless path

        options[:as]  ||= app_name(app)
        target_as       = name_for_action(options[:as], path)
        options[:via] ||= :all

        match(path, options.merge(:to => app, :anchor => false, :format => false))

        define_generate_prefix(app, target_as)
        self
      end

      # DSL
      # ===
      def scope(*args, &block)
        new_scope = Scope.new(*args)
        new_scope.parent = self
        new_scope.instance_exec(&bloc)
        @routes += new_scope.routes
      end

      def controller(controller, options={})
        options[:controller] = controller
        scope(options) { yield }
      end

      def defaults(defaults = {})
        scope(:defaults => defaults) { yield }
      end

      def namespace(path, options = {})
        path = path.to_s

        defaults = {
          module:         path,
          path:           options.fetch(:path, path),
          as:             options.fetch(:as, path),
          shallow_path:   options.fetch(:path, path),
          shallow_prefix: options.fetch(:as, path)
        }

        scope(defaults.merge!(options)) { yield }
      end

      def constraints(constraints = {})
        scope(:constraints => constraints) { yield }
      end

      def concern(name, callable = nil, &block)
        callable ||= lambda { |mapper, options| mapper.instance_exec(options, &block) }
        @concerns[name] = callable
      end

      def concerns(*args)
        options = args.extract_options!
        args.flatten.each do |name|
          if concern = @concerns[name]
            concern.call(self, options)
          else
            raise ArgumentError, "No concern named #{name} was found!"
          end
        end
      end

      def shallow?
        false
      end

      def using_match_shorthand?(path, options)
        path && (options[:to] || options[:action]).nil? && path =~ %r{/[\w/]+$}
      end

      def decomposed_match(path, options) # :nodoc:
        if on = options.delete(:on)
          send(on) { decomposed_match(path, options) }
        else
          case @scope[:scope_level]
          when :resources
            nested { decomposed_match(path, options) }
          when :resource
            member { decomposed_match(path, options) }
          else
            add_route(path, options)
          end
        end
      end

      def add_route(action, options) # :nodoc:
        path = path_for_action(action, options.delete(:path))
        raise ArgumentError, "path is required" if path.blank?

        action = action.to_s.dup

        if action =~ /^[\w\-\/]+$/
          options[:action] ||= action.tr('-', '_') unless action.include?("/")
        else
          action = nil
        end

        if !options.fetch(:as, true)
          options.delete(:as)
        else
          options[:as] = name_for_action(options[:as], action)
        end

        mapping = Mapping.build(@scope, URI.parser.escape(path), options)
        app, conditions, requirements, defaults, as, anchor = mapping.to_route
        @set.add_route(app, conditions, requirements, defaults, as, anchor)
      end

      private
        def map_method(method, args, &block)
          options = args.extract_options!
          options[:via] = method
          match(*args, options, &block)
          self
        end

        def default_url_options=(options)
          @set.default_url_options = options
        end
        alias_method :default_url_options, :default_url_options=

        # Query if the following named route was already defined.
        def has_named_route?(name)
          @set.named_routes.routes[name.to_sym]
        end
        def app_name(app)
          return unless app.respond_to?(:routes)

          if app.respond_to?(:railtie_name)
            app.railtie_name
          else
            class_name = app.class.is_a?(Class) ? app.name : app.class.name
            ActiveSupport::Inflector.underscore(class_name).tr("/", "_")
          end
        end

        def define_generate_prefix(app, name)
          return unless app.respond_to?(:routes) && app.routes.respond_to?(:define_mounted_helper)

          _route = @set.named_routes.routes[name.to_sym]
          _routes = @set
          app.routes.define_mounted_helper(name)
          app.routes.extend Module.new {
            def mounted?; true; end
            define_method :find_script_name do |options|
              super(options) || begin
              prefix_options = options.slice(*_route.segment_keys)
              # we must actually delete prefix segment keys to avoid passing them to next url_for
              _route.segment_keys.each { |k| options.delete(k) }
              _routes.url_helpers.send("#{name}_path", prefix_options)
              end
            end
          }
        end
    end
  end
end
