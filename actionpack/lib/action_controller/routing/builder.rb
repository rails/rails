module ActionController
  module Routing
    class RouteBuilder #:nodoc:
      attr_accessor :separators, :optional_separators

      def initialize
        self.separators = Routing::SEPARATORS
        self.optional_separators = %w( / )
      end

      def separator_pattern(inverted = false)
        "[#{'^' if inverted}#{Regexp.escape(separators.join)}]"
      end

      def interval_regexp
        Regexp.new "(.*?)(#{separators.source}|$)"
      end

      def multiline_regexp?(expression)
        expression.options & Regexp::MULTILINE == Regexp::MULTILINE
      end

      # Accepts a "route path" (a string defining a route), and returns the array
      # of segments that corresponds to it. Note that the segment array is only
      # partially initialized--the defaults and requirements, for instance, need
      # to be set separately, via the +assign_route_options+ method, and the
      # <tt>optional?</tt> method for each segment will not be reliable until after
      # +assign_route_options+ is called, as well.
      def segments_for_route_path(path)
        rest, segments = path, []

        until rest.empty?
          segment, rest = segment_for rest
          segments << segment
        end
        segments
      end

      # A factory method that returns a new segment instance appropriate for the
      # format of the given string.
      def segment_for(string)
        segment = case string
          when /\A:(\w+)/
            key = $1.to_sym
            case key
              when :controller then ControllerSegment.new(key)
              else DynamicSegment.new key
            end
          when /\A\*(\w+)/ then PathSegment.new($1.to_sym, :optional => true)
          when /\A\?(.*?)\?/
            returning segment = StaticSegment.new($1) do
              segment.is_optional = true
            end
          when /\A(#{separator_pattern(:inverted)}+)/ then StaticSegment.new($1)
          when Regexp.new(separator_pattern) then
            returning segment = DividerSegment.new($&) do
              segment.is_optional = (optional_separators.include? $&)
            end
        end
        [segment, $~.post_match]
      end

      # Split the given hash of options into requirement and default hashes. The
      # segments are passed alongside in order to distinguish between default values
      # and requirements.
      def divide_route_options(segments, options)
        options = options.dup

        if options[:namespace]
          options[:controller] = "#{options[:path_prefix]}/#{options[:controller]}"
          options.delete(:path_prefix)
          options.delete(:name_prefix)
          options.delete(:namespace)
        end

        requirements = (options.delete(:requirements) || {}).dup
        defaults     = (options.delete(:defaults)     || {}).dup
        conditions   = (options.delete(:conditions)   || {}).dup

        path_keys = segments.collect { |segment| segment.key if segment.respond_to?(:key) }.compact
        options.each do |key, value|
          hash = (path_keys.include?(key) && ! value.is_a?(Regexp)) ? defaults : requirements
          hash[key] = value
        end

        [defaults, requirements, conditions]
      end

      # Takes a hash of defaults and a hash of requirements, and assigns them to
      # the segments. Any unused requirements (which do not correspond to a segment)
      # are returned as a hash.
      def assign_route_options(segments, defaults, requirements)
        route_requirements = {} # Requirements that do not belong to a segment

        segment_named = Proc.new do |key|
          segments.detect { |segment| segment.key == key if segment.respond_to?(:key) }
        end

        requirements.each do |key, requirement|
          segment = segment_named[key]
          if segment
            raise TypeError, "#{key}: requirements on a path segment must be regular expressions" unless requirement.is_a?(Regexp)
            if requirement.source =~ %r{\A(\\A|\^)|(\\Z|\\z|\$)\Z}
              raise ArgumentError, "Regexp anchor characters are not allowed in routing requirements: #{requirement.inspect}"
            end
            if multiline_regexp?(requirement)
              raise ArgumentError, "Regexp multiline option not allowed in routing requirements: #{requirement.inspect}"
            end
            segment.regexp = requirement
          else
            route_requirements[key] = requirement
          end
        end

        defaults.each do |key, default|
          segment = segment_named[key]
          raise ArgumentError, "#{key}: No matching segment exists; cannot assign default" unless segment
          segment.is_optional = true
          segment.default = default.to_param if default
        end

        assign_default_route_options(segments)
        ensure_required_segments(segments)
        route_requirements
      end

      # Assign default options, such as 'index' as a default for <tt>:action</tt>. This
      # method must be run *after* user supplied requirements and defaults have
      # been applied to the segments.
      def assign_default_route_options(segments)
        segments.each do |segment|
          next unless segment.is_a? DynamicSegment
          case segment.key
            when :action
              if segment.regexp.nil? || segment.regexp.match('index').to_s == 'index'
                segment.default ||= 'index'
                segment.is_optional = true
              end
            when :id
              if segment.default.nil? && segment.regexp.nil? || segment.regexp =~ ''
                segment.is_optional = true
              end
          end
        end
      end

      # Makes sure that there are no optional segments that precede a required
      # segment. If any are found that precede a required segment, they are
      # made required.
      def ensure_required_segments(segments)
        allow_optional = true
        segments.reverse_each do |segment|
          allow_optional &&= segment.optional?
          if !allow_optional && segment.optional?
            unless segment.optionality_implied?
              warn "Route segment \"#{segment.to_s}\" cannot be optional because it precedes a required segment. This segment will be required."
            end
            segment.is_optional = false
          elsif allow_optional && segment.respond_to?(:default) && segment.default
            # if a segment has a default, then it is optional
            segment.is_optional = true
          end
        end
      end

      # Construct and return a route with the given path and options.
      def build(path, options)
        # Wrap the path with slashes
        path = "/#{path}" unless path[0] == ?/
        path = "#{path}/" unless path[-1] == ?/

        path = "/#{options[:path_prefix].to_s.gsub(/^\//,'')}#{path}" if options[:path_prefix]

        segments = segments_for_route_path(path)
        defaults, requirements, conditions = divide_route_options(segments, options)
        requirements = assign_route_options(segments, defaults, requirements)

        route = Route.new

        route.segments = segments
        route.requirements = requirements
        route.conditions = conditions

        if !route.significant_keys.include?(:action) && !route.requirements[:action]
          route.requirements[:action] = "index"
          route.significant_keys << :action
        end

        # Routes cannot use the current string interpolation method
        # if there are user-supplied <tt>:requirements</tt> as the interpolation
        # code won't raise RoutingErrors when generating
        if options.key?(:requirements) || route.requirements.keys.to_set != Routing::ALLOWED_REQUIREMENTS_FOR_OPTIMISATION
          route.optimise = false
        end

        if !route.significant_keys.include?(:controller)
          raise ArgumentError, "Illegal route: the :controller must be specified!"
        end

        route
      end
    end
  end
end
