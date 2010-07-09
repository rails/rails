require 'rack/mount/generatable_regexp'
require 'rack/mount/regexp_with_named_groups'
require 'rack/mount/utils'

module Rack::Mount
  # Route is an internal class used to wrap a single route attributes.
  #
  # Plugins should not depend on any method on this class or instantiate
  # new Route objects. Instead use the factory method, RouteSet#add_route
  # to create new routes and add them to the set.
  class Route
    # Valid rack application to call if conditions are met
    attr_reader :app

    # A hash of conditions to match against. Conditions may be expressed
    # as strings or regexps to match against.
    attr_reader :conditions

    # A hash of values that always gets merged into the parameters hash
    attr_reader :defaults

    # Symbol identifier for the route used with named route generations
    attr_reader :name

    attr_reader :named_captures

    def initialize(app, conditions, defaults, name)
      unless app.respond_to?(:call)
        raise ArgumentError, 'app must be a valid rack application' \
          ' and respond to call'
      end
      @app = app

      @name = name ? name.to_sym : nil
      @defaults = (defaults || {}).freeze

      @conditions = {}

      conditions.each do |method, pattern|
        next unless method && pattern

        pattern = Regexp.compile("\\A#{Regexp.escape(pattern)}\\Z") if pattern.is_a?(String)

        if pattern.is_a?(Regexp)
          pattern = Utils.normalize_extended_expression(pattern)
          pattern = RegexpWithNamedGroups.new(pattern)
          pattern.extend(GeneratableRegexp::InstanceMethods)
          pattern.defaults = @defaults
        end

        @conditions[method] = pattern.freeze
      end

      @named_captures = {}
      @conditions.map { |method, condition|
        next unless condition.respond_to?(:named_captures)
        @named_captures[method] = condition.named_captures.inject({}) { |named_captures, (k, v)|
          named_captures[k.to_sym] = v.last - 1
          named_captures
        }.freeze
      }
      @named_captures.freeze

      @has_significant_params = @conditions.any? { |method, condition|
        (condition.respond_to?(:required_params) && condition.required_params.any?) ||
          (condition.respond_to?(:required_defaults) && condition.required_defaults.any?)
      }

      if @conditions.has_key?(:path_info) &&
          !Utils.regexp_anchored?(@conditions[:path_info])
        @prefix = true
        @app = Prefix.new(@app)
      else
        @prefix = false
      end

      @conditions.freeze
    end

    def prefix?
      @prefix
    end


    def generation_keys
      @conditions.inject({}) { |keys, (method, condition)|
        if condition.respond_to?(:required_defaults)
          keys.merge!(condition.required_defaults)
        else
          keys
        end
      }
    end

    def significant_params?
      @has_significant_params
    end

    def generate(method, params = {}, recall = {}, options = {})
      if method.nil?
        result = @conditions.inject({}) { |h, (m, condition)|
          if condition.respond_to?(:generate)
            h[m] = condition.generate(params, recall, options)
          end
          h
        }
        return nil if result.values.compact.empty?
      else
        if condition = @conditions[method]
          if condition.respond_to?(:generate)
            result = condition.generate(params, recall, options)
          end
        end
      end

      if result
        @defaults.each do |key, value|
          params.delete(key) if params[key] == value
        end
      end

      result
    end


    def inspect #:nodoc:
      "#<#{self.class.name} @app=#{@app.inspect} @conditions=#{@conditions.inspect} @defaults=#{@defaults.inspect} @name=#{@name.inspect}>"
    end
  end
end
