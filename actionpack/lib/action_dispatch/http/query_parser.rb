# frozen_string_literal: true

require "rack/utils"

module ActionDispatch
  class QueryParser
    DEFAULT_SEP = /[&;] */n
    COMMON_SEP = { ";" => /[;] */n, ";," => /[;,] */n, "&" => /[&] */n }

    ParameterTypeError = ::Rack::QueryParser::ParameterTypeError
    InvalidParameterError = ::Rack::QueryParser::InvalidParameterError
    ParamsTooDeepError = ::Rack::QueryParser::ParamsTooDeepError

    def self.make_default(key_space_limit = 65536, param_depth_limit = 100)
      new Params, key_space_limit, param_depth_limit
    end

    attr_reader :key_space_limit, :param_depth_limit

    def initialize(params_class, key_space_limit, param_depth_limit)
      @params_class = params_class
      @key_space_limit = key_space_limit
      @param_depth_limit = param_depth_limit
    end

    # Stolen from Mongrel, with some small modifications:
    # Parses a query string by breaking it up at the '&'
    # and ';' characters.  You can also use this to parse
    # cookies by changing the characters used in the second
    # parameter (which defaults to '&;').
    def parse_query(qs, d = nil, &unescaper)
      unescaper ||= method(:unescape)

      params = make_params

      (qs || "").split(d ? (COMMON_SEP[d] || /[#{d}] */n) : DEFAULT_SEP).each do |p|
        next if p.empty?
        k, v = p.split("=", 2).map!(&unescaper)

        if cur = params[k]
          if cur.class == Array
            params[k] << v
          else
            params[k] = [cur, v]
          end
        else
          params[k] = v
        end
      end

      params.to_h
    end

    # parse_nested_query expands a query string into structural types. Supported
    # types are Arrays, Hashes and basic value types. It is possible to supply
    # query strings with parameters of conflicting types, in this case a
    # ParameterTypeError is raised. Users are encouraged to return a 400 in this
    # case.
    def parse_nested_query(qs, d = nil)
      params = make_params

      unless qs.nil? || qs.empty?
        (qs || "").split(d ? (COMMON_SEP[d] || /[#{d}] */n) : DEFAULT_SEP).each do |p|
          k, v = p.split("=", 2).map! { |s| unescape(s) }

          normalize_params(params, k, v, param_depth_limit)
        end
      end

      params.to_h
    rescue ArgumentError => e
      raise InvalidParameterError, e.message, e.backtrace
    end

    # normalize_params recursively expands parameters into structural types. If
    # the structural types represented by two different parameter names are in
    # conflict, a ParameterTypeError is raised.
    def normalize_params(params, name, v, depth = param_depth_limit)
      raise ParamsTooDeepError if depth <= 0

      name =~ %r(\A[\[\]]*([^\[\]]+)\]*)
      k = $1 || ""
      after = $' || ""

      if k.empty?
        if !v.nil? && name == "[]"
          return Array(v)
        else
          return
        end
      end

      if after == ""
        params[k] = v
      elsif after == "["
        params[name] = v
      elsif after == "[]"
        params[k] ||= []
        raise ParameterTypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        params[k] << v
      elsif after =~ %r(^\[\]\[([^\[\]]+)\]$) || after =~ %r(^\[\](.+)$)
        child_key = $1
        params[k] ||= []
        raise ParameterTypeError, "expected Array (got #{params[k].class.name}) for param `#{k}'" unless params[k].is_a?(Array)
        if params_hash_type?(params[k].last) && !params_hash_has_key?(params[k].last, child_key)
          normalize_params(params[k].last, child_key, v, depth - 1)
        else
          params[k] << normalize_params(make_params, child_key, v, depth - 1)
        end
      else
        params[k] ||= make_params
        raise ParameterTypeError, "expected Hash (got #{params[k].class.name}) for param `#{k}'" unless params_hash_type?(params[k])
        params[k] = normalize_params(params[k], after, v, depth - 1)
      end

      params
    end

    def make_params
      @params_class.new @key_space_limit
    end

    def new_space_limit(key_space_limit)
      self.class.new @params_class, key_space_limit, param_depth_limit
    end

    def new_depth_limit(param_depth_limit)
      self.class.new @params_class, key_space_limit, param_depth_limit
    end

    private
      def params_hash_type?(obj)
        obj.kind_of?(@params_class)
      end

      def params_hash_has_key?(hash, key)
        return false if key.include?("[]")

        key.split(/[\[\]]+/).inject(hash) do |h, part|
          next h if part == ""
          return false unless params_hash_type?(h) && h.key?(part)
          h[part]
        end

        true
      end

      def unescape(s)
        ::Rack::Utils.unescape(s)
      end

      class Params
        def initialize(limit)
          @limit  = limit
          @size   = 0
          @params = {}
        end

        def [](key)
          @params[key]
        end

        def []=(key, value)
          @size += key.size if key && !@params.key?(key)
          raise ParamsTooDeepError, "exceeded available parameter key space" if @size > @limit
          @params[key] = value
        end

        def key?(key)
          @params.key?(key)
        end

        # Recursively unwraps nested `Params` objects and constructs an object
        # of the same shape, but using the objects' internal representations
        # (Ruby hashes) in place of the objects. The result is a hash consisting
        # purely of Ruby primitives.
        #
        #   Mutation warning!
        #
        #   1. This method mutates the internal representation of the `Params`
        #      objects in order to save object allocations.
        #
        #   2. The value you get back is a reference to the internal hash
        #      representation, not a copy.
        #
        #   3. Because the `Params` object's internal representation is mutable
        #      through the `#[]=` method, it is not thread safe. The result of
        #      getting the hash representation while another thread is adding a
        #      key to it is non-deterministic.
        #
        def to_h
          @params.each do |key, value|
            case value
            when self
              # Handle circular references gracefully.
              @params[key] = @params
            when Params
              @params[key] = value.to_h
            when Array
              value.map! { |v| v.kind_of?(Params) ? v.to_h : v }
            else
              # Ignore anything that is not a `Params` object or
              # a collection that can contain one.
            end
          end
          @params
        end
        alias_method :to_params_hash, :to_h
      end
  end
end

# Replace the Rack query parser with the non-standard Rack 2.2 implementation.
# See <https://github.com/rails/rails/pull/47080> for more details.
Rack::Utils.default_query_parser = ActionDispatch::QueryParser.make_default
