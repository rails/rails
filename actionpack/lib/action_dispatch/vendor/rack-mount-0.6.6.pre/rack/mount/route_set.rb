require 'rack/mount/multimap'
require 'rack/mount/route'
require 'rack/mount/utils'

module Rack::Mount
  class RoutingError < StandardError; end

  class RouteSet
    # Initialize a new RouteSet without optimizations
    def self.new_without_optimizations(options = {}, &block)
      new(options.merge(:_optimize => false), &block)
    end

    # Basic RouteSet initializer.
    #
    # If a block is given, the set is yielded and finalized.
    #
    # See other aspects for other valid options:
    # - <tt>Generation::RouteSet.new</tt>
    # - <tt>Recognition::RouteSet.new</tt>
    def initialize(options = {}, &block)
      @parameters_key = options.delete(:parameters_key) || 'rack.routing_args'
      @parameters_key.freeze

      @named_routes = {}

      @recognition_key_analyzer = Analysis::Splitting.new
      @generation_key_analyzer  = Analysis::Frequency.new

      @request_class = options.delete(:request_class) || Rack::Request
      @valid_conditions = @request_class.public_instance_methods.map! { |m| m.to_sym }

      extend CodeGeneration unless options[:_optimize] == false
      @optimized_recognize_defined = false

      @routes = []
      expire!

      if block_given?
        yield self
        rehash
      end
    end

    # Builder method to add a route to the set
    #
    # <tt>app</tt>:: A valid Rack app to call if the conditions are met.
    # <tt>conditions</tt>:: A hash of conditions to match against.
    #                       Conditions may be expressed as strings or
    #                       regexps to match against.
    # <tt>defaults</tt>:: A hash of values that always gets merged in
    # <tt>name</tt>:: Symbol identifier for the route used with named
    #                 route generations
    def add_route(app, conditions = {}, defaults = {}, name = nil)
      unless conditions.is_a?(Hash)
        raise ArgumentError, 'conditions must be a Hash'
      end

      unless conditions.all? { |method, pattern|
          @valid_conditions.include?(method)
        }
        raise ArgumentError, 'conditions may only include ' +
          @valid_conditions.inspect
      end

      route = Route.new(app, conditions, defaults, name)
      @routes << route

      @recognition_key_analyzer << route.conditions

      @named_routes[route.name] = route if route.name
      @generation_key_analyzer << route.generation_keys

      expire!
      route
    end

    def recognize(obj)
      raise 'route set not finalized' unless @recognition_graph

      cache = {}
      keys = @recognition_keys.map { |key|
        if key.respond_to?(:call)
          key.call(cache, obj)
        else
          obj.send(key)
        end
      }

      @recognition_graph[*keys].each do |route|
        matches = {}
        params  = route.defaults.dup

        if route.conditions.all? { |method, condition|
            value = obj.send(method)
            if condition.is_a?(Regexp) && (m = value.match(condition))
              matches[method] = m
              captures = m.captures
              route.named_captures[method].each do |k, i|
                if v = captures[i]
                  params[k] = v
                end
              end
              true
            elsif value == condition
              true
            else
              false
            end
          }
          if block_given?
            yield route, matches, params
          else
            return route, matches, params
          end
        end
      end

      nil
    end

    X_CASCADE = 'X-Cascade'.freeze
    PASS      = 'pass'.freeze
    PATH_INFO = 'PATH_INFO'.freeze

    # Rack compatible recognition and dispatching method. Routes are
    # tried until one returns a non-catch status code. If no routes
    # match, the catch status code is returned.
    #
    # This method can only be invoked after the RouteSet has been
    # finalized.
    def call(env)
      raise 'route set not finalized' unless @recognition_graph

      env[PATH_INFO] = Utils.normalize_path(env[PATH_INFO])

      request = nil
      req = @request_class.new(env)
      recognize(req) do |route, matches, params|
        # TODO: We only want to unescape params from uri related methods
        params.each { |k, v| params[k] = Utils.unescape_uri(v) if v.is_a?(String) }

        if route.prefix?
          env[Prefix::KEY] = matches[:path_info].to_s
        end

        env[@parameters_key] = params
        result = route.app.call(env)
        return result unless result[1][X_CASCADE] == PASS
      end

      request || [404, {'Content-Type' => 'text/html', 'X-Cascade' => 'pass'}, ['Not Found']]
    end

    # Generates a url from Rack env and identifiers or significant keys.
    #
    # To generate a url by named route, pass the name in as a +Symbol+.
    #   url(env, :dashboard) # => "/dashboard"
    #
    # Additional parameters can be passed in as a hash
    #   url(env, :people, :id => "1") # => "/people/1"
    #
    # If no name route is given, it will fall back to a slower
    # generation search.
    #   url(env, :controller => "people", :action => "show", :id => "1")
    #     # => "/people/1"
    def url(env, *args)
      named_route, params = nil, {}

      case args.length
      when 2
        named_route, params = args[0], args[1].dup
      when 1
        if args[0].is_a?(Hash)
          params = args[0].dup
        else
          named_route = args[0]
        end
      else
        raise ArgumentError
      end

      only_path = params.delete(:only_path)
      recall = env[@parameters_key] || {}

      unless result = generate(:all, named_route, params, recall,
          :parameterize => lambda { |name, param| Utils.escape_uri(param) })
        return
      end

      parts, params = result
      return unless parts

      params.each do |k, v|
        if v
          params[k] = v
        else
          params.delete(k)
        end
      end

      req = stubbed_request_class.new(env)
      req._stubbed_values = parts.merge(:query_string => Utils.build_nested_query(params))
      only_path ? req.fullpath : req.url
    end

    def generate(method, *args) #:nodoc:
      raise 'route set not finalized' unless @generation_graph

      method = nil if method == :all
      named_route, params, recall, options = extract_params!(*args)
      merged = recall.merge(params)
      route = nil

      if named_route
        if route = @named_routes[named_route.to_sym]
          recall = route.defaults.merge(recall)
          url = route.generate(method, params, recall, options)
          [url, params]
        else
          raise RoutingError, "#{named_route} failed to generate from #{params.inspect}"
        end
      else
        keys = @generation_keys.map { |key|
          if k = merged[key]
            k.to_s
          else
            nil
          end
        }
        @generation_graph[*keys].each do |r|
          next unless r.significant_params?
          if url = r.generate(method, params, recall, options)
            return [url, params]
          end
        end

        raise RoutingError, "No route matches #{params.inspect}"
      end
    end

    # Number of routes in the set
    def length
      @routes.length
    end

    def rehash #:nodoc:
      @recognition_keys  = build_recognition_keys
      @recognition_graph = build_recognition_graph
      @generation_keys   = build_generation_keys
      @generation_graph  = build_generation_graph
    end

    # Finalizes the set and builds optimized data structures. You *must*
    # freeze the set before you can use <tt>call</tt> and <tt>url</tt>.
    # So remember to call freeze after you are done adding routes.
    def freeze
      unless frozen?
        rehash

        @recognition_key_analyzer = nil
        @generation_key_analyzer  = nil
        @valid_conditions         = nil

        @routes.each { |route| route.freeze }
        @routes.freeze
      end

      super
    end

    def marshal_dump #:nodoc:
      hash = {}

      instance_variables_to_serialize.each do |ivar|
        hash[ivar] = instance_variable_get(ivar)
      end

      if graph = hash[:@recognition_graph]
        hash[:@recognition_graph] = graph.dup
      end

      hash
    end

    def marshal_load(hash) #:nodoc:
      hash.each do |ivar, value|
        instance_variable_set(ivar, value)
      end
    end

    protected
      def recognition_stats
        { :keys => @recognition_keys,
          :keys_size => @recognition_keys.size,
          :graph_size => @recognition_graph.size,
          :graph_height => @recognition_graph.height,
          :graph_average_height => @recognition_graph.average_height }
      end

    private
      def expire! #:nodoc:
        @recognition_keys = @recognition_graph = nil
        @recognition_key_analyzer.expire!

        @generation_keys = @generation_graph = nil
        @generation_key_analyzer.expire!
      end

      def instance_variables_to_serialize
        instance_variables.map { |ivar| ivar.to_sym } - [:@stubbed_request_class, :@optimized_recognize_defined]
      end

      # An internal helper method for constructing a nested set from
      # the linear route set.
      #
      # build_nested_route_set([:request_method, :path_info]) { |route, method|
      #   route.send(method)
      # }
      def build_nested_route_set(keys, &block)
        graph = Multimap.new
        @routes.each_with_index do |route, index|
          catch(:skip) do
            k = keys.map { |key| block.call(key, index) }
            Utils.pop_trailing_nils!(k)
            k.map! { |key| key || /.+/ }
            graph[*k] = route
          end
        end
        graph
      end

      def build_recognition_graph
        build_nested_route_set(@recognition_keys) { |k, i|
          @recognition_key_analyzer.possible_keys[i][k]
        }
      end

      def build_recognition_keys
        @recognition_key_analyzer.report
      end

      def build_generation_graph
        build_nested_route_set(@generation_keys) { |k, i|
          throw :skip unless @routes[i].significant_params?

          if k = @generation_key_analyzer.possible_keys[i][k]
            k.to_s
          else
            nil
          end
        }
      end

      def build_generation_keys
        @generation_key_analyzer.report
      end

      def extract_params!(*args)
        case args.length
        when 4
          named_route, params, recall, options = args
        when 3
          if args[0].is_a?(Hash)
            params, recall, options = args
          else
            named_route, params, recall = args
          end
        when 2
          if args[0].is_a?(Hash)
            params, recall = args
          else
            named_route, params = args
          end
        when 1
          if args[0].is_a?(Hash)
            params = args[0]
          else
            named_route = args[0]
          end
        else
          raise ArgumentError
        end

        named_route ||= nil
        params  ||= {}
        recall  ||= {}
        options ||= {}

        [named_route, params.dup, recall.dup, options.dup]
      end

      def stubbed_request_class
        @stubbed_request_class ||= begin
          klass = Class.new(@request_class)
          klass.public_instance_methods.each do |method|
            next if method =~ /^__|object_id/
            klass.class_eval <<-RUBY
              def #{method}(*args, &block)
                @_stubbed_values[:#{method}] || super
              end
            RUBY
          end
          klass.class_eval { attr_accessor :_stubbed_values }
          klass
        end
      end
  end
end
