module ActionDispatch
  module Journey # :nodoc:
    class Route # :nodoc:
      attr_reader :app, :path, :verb, :defaults, :ip, :name

      attr_reader :constraints
      alias :conditions :constraints

      attr_accessor :precedence

      ##
      # +path+ is a path constraint.
      # +constraints+ is a hash of constraints to be applied to this route.
      def initialize(name, app, path, constraints, defaults = {})
        constraints  = constraints.dup
        @name        = name
        @app         = app
        @path        = path
        @verb        = constraints[:request_method] || //
        @ip          = constraints.delete(:ip) || //

        @constraints = constraints
        @constraints.keep_if { |_,v| Regexp === v || String === v }
        @defaults    = defaults
        @required_defaults = nil
        @required_parts    = nil
        @parts             = nil
        @decorated_ast     = nil
        @precedence        = 0
      end

      def ast
        return @decorated_ast if @decorated_ast

        @decorated_ast = path.ast
        @decorated_ast.grep(Nodes::Terminal).each { |n| n.memo = self }
        @decorated_ast
      end

      def requirements # :nodoc:
        # needed for rails `rake routes`
        path.requirements.merge(@defaults).delete_if { |_,v|
          /.+?/ == v
        }
      end

      def segments
        @path.names
      end

      def required_keys
        path.required_names.map { |x| x.to_sym } + required_defaults.keys
      end

      def score(constraints)
        required_keys = path.required_names
        supplied_keys = constraints.map { |k,v| v && k.to_s }.compact

        return -1 unless (required_keys - supplied_keys).empty?

        score = (supplied_keys & path.names).length
        score + (required_defaults.length * 2)
      end

      def parts
        @parts ||= segments.map { |n| n.to_sym }
      end
      alias :segment_keys :parts

      def format(path_options)
        path_options.delete_if do |key, value|
          value.to_s == defaults[key].to_s && !required_parts.include?(key)
        end

        Visitors::Formatter.new(path_options).accept(path.spec)
      end

      def optional_parts
        path.optional_names.map { |n| n.to_sym }
      end

      def required_parts
        @required_parts ||= path.required_names.map { |n| n.to_sym }
      end

      def required_defaults
        @required_defaults ||= begin
          matches = parts
          @defaults.dup.delete_if { |k,_| matches.include?(k) }
        end
      end
    end
  end
end
