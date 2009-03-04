module ActionController
  module Routing
    class Segment #:nodoc:
      RESERVED_PCHAR = ':@&=+$,;'
      SAFE_PCHAR = "#{URI::REGEXP::PATTERN::UNRESERVED}#{RESERVED_PCHAR}"
      if RUBY_VERSION >= '1.9'
        UNSAFE_PCHAR = Regexp.new("[^#{SAFE_PCHAR}]", false).freeze
      else
        UNSAFE_PCHAR = Regexp.new("[^#{SAFE_PCHAR}]", false, 'N').freeze
      end

      # TODO: Convert :is_optional accessor to read only
      attr_accessor :is_optional
      alias_method :optional?, :is_optional

      def initialize
        @is_optional = false
      end

      def number_of_captures
        Regexp.new(regexp_chunk).number_of_captures
      end

      def extraction_code
        nil
      end

      # Continue generating string for the prior segments.
      def continue_string_structure(prior_segments)
        if prior_segments.empty?
          interpolation_statement(prior_segments)
        else
          new_priors = prior_segments[0..-2]
          prior_segments.last.string_structure(new_priors)
        end
      end

      def interpolation_chunk
        URI.escape(value, UNSAFE_PCHAR)
      end

      # Return a string interpolation statement for this segment and those before it.
      def interpolation_statement(prior_segments)
        chunks = prior_segments.collect { |s| s.interpolation_chunk }
        chunks << interpolation_chunk
        "\"#{chunks * ''}\"#{all_optionals_available_condition(prior_segments)}"
      end

      def string_structure(prior_segments)
        optional? ? continue_string_structure(prior_segments) : interpolation_statement(prior_segments)
      end

      # Return an if condition that is true if all the prior segments can be generated.
      # If there are no optional segments before this one, then nil is returned.
      def all_optionals_available_condition(prior_segments)
        optional_locals = prior_segments.collect { |s| s.local_name if s.optional? && s.respond_to?(:local_name) }.compact
        optional_locals.empty? ? nil : " if #{optional_locals * ' && '}"
      end

      # Recognition

      def match_extraction(next_capture)
        nil
      end

      # Warning

      # Returns true if this segment is optional? because of a default. If so, then
      # no warning will be emitted regarding this segment.
      def optionality_implied?
        false
      end
    end

    class StaticSegment < Segment #:nodoc:
      attr_reader :value, :raw
      alias_method :raw?, :raw

      def initialize(value = nil, options = {})
        super()
        @value = value
        @raw = options[:raw] if options.key?(:raw)
        @is_optional = options[:optional] if options.key?(:optional)
      end

      def interpolation_chunk
        raw? ? value : super
      end

      def regexp_chunk
        chunk = Regexp.escape(value)
        optional? ? Regexp.optionalize(chunk) : chunk
      end

      def number_of_captures
        0
      end

      def build_pattern(pattern)
        escaped = Regexp.escape(value)
        if optional? && ! pattern.empty?
          "(?:#{Regexp.optionalize escaped}\\Z|#{escaped}#{Regexp.unoptionalize pattern})"
        elsif optional?
          Regexp.optionalize escaped
        else
          escaped + pattern
        end
      end

      def to_s
        value
      end
    end

    class DividerSegment < StaticSegment #:nodoc:
      def initialize(value = nil, options = {})
        super(value, {:raw => true, :optional => true}.merge(options))
      end

      def optionality_implied?
        true
      end
    end

    class DynamicSegment < Segment #:nodoc:
      attr_reader :key

      # TODO: Convert these accessors to read only
      attr_accessor :default, :regexp

      def initialize(key = nil, options = {})
        super()
        @key = key
        @default = options[:default] if options.key?(:default)
        @regexp = options[:regexp] if options.key?(:regexp)
        @is_optional = true if options[:optional] || options.key?(:default)
      end

      def to_s
        ":#{key}"
      end

      # The local variable name that the value of this segment will be extracted to.
      def local_name
        "#{key}_value"
      end

      def extract_value
        "#{local_name} = hash[:#{key}] && hash[:#{key}].to_param #{"|| #{default.inspect}" if default}"
      end

      def value_check
        if default # Then we know it won't be nil
          "#{value_regexp.inspect} =~ #{local_name}" if regexp
        elsif optional?
          # If we have a regexp check that the value is not given, or that it matches.
          # If we have no regexp, return nil since we do not require a condition.
          "#{local_name}.nil? || #{value_regexp.inspect} =~ #{local_name}" if regexp
        else # Then it must be present, and if we have a regexp, it must match too.
          "#{local_name} #{"&& #{value_regexp.inspect} =~ #{local_name}" if regexp}"
        end
      end

      def expiry_statement
        "expired, hash = true, options if !expired && expire_on[:#{key}]"
      end

      def extraction_code
        s = extract_value
        vc = value_check
        s << "\nreturn [nil,nil] unless #{vc}" if vc
        s << "\n#{expiry_statement}"
      end

      def interpolation_chunk(value_code = local_name)
        "\#{URI.escape(#{value_code}.to_s, ActionController::Routing::Segment::UNSAFE_PCHAR)}"
      end

      def string_structure(prior_segments)
        if optional? # We have a conditional to do...
          # If we should not appear in the url, just write the code for the prior
          # segments. This occurs if our value is the default value, or, if we are
          # optional, if we have nil as our value.
          "if #{local_name} == #{default.inspect}\n" +
            continue_string_structure(prior_segments) +
          "\nelse\n" + # Otherwise, write the code up to here
            "#{interpolation_statement(prior_segments)}\nend"
        else
          interpolation_statement(prior_segments)
        end
      end

      def value_regexp
        Regexp.new "\\A#{regexp.to_s}\\Z" if regexp
      end

      def regexp_chunk
        regexp ? regexp_string : default_regexp_chunk
      end

      def regexp_string
        regexp_has_modifiers? ? "(#{regexp.to_s})" : "(#{regexp.source})"
      end

      def default_regexp_chunk
        "([^#{Routing::SEPARATORS.join}]+)"
      end

      def number_of_captures
        regexp ? regexp.number_of_captures + 1 : 1
      end

      def build_pattern(pattern)
        pattern = "#{regexp_chunk}#{pattern}"
        optional? ? Regexp.optionalize(pattern) : pattern
      end

      def match_extraction(next_capture)
        # All non code-related keys (such as :id, :slug) are URI-unescaped as
        # path parameters.
        default_value = default ? default.inspect : nil
        %[
          value = if (m = match[#{next_capture}])
            URI.unescape(m)
          else
            #{default_value}
          end
          params[:#{key}] = value if value
        ]
      end

      def optionality_implied?
        [:action, :id].include? key
      end

      def regexp_has_modifiers?
        regexp.options & (Regexp::IGNORECASE | Regexp::EXTENDED) != 0
      end
    end

    class ControllerSegment < DynamicSegment #:nodoc:
      def regexp_chunk
        possible_names = Routing.possible_controllers.collect { |name| Regexp.escape name }
        "(?i-:(#{(regexp || Regexp.union(*possible_names)).source}))"
      end

      # Don't URI.escape the controller name since it may contain slashes.
      def interpolation_chunk(value_code = local_name)
        "\#{#{value_code}.to_s}"
      end

      # Make sure controller names like Admin/Content are correctly normalized to
      # admin/content
      def extract_value
        "#{local_name} = (hash[:#{key}] #{"|| #{default.inspect}" if default}).downcase"
      end

      def match_extraction(next_capture)
        if default
          "params[:#{key}] = match[#{next_capture}] ? match[#{next_capture}].downcase : '#{default}'"
        else
          "params[:#{key}] = match[#{next_capture}].downcase if match[#{next_capture}]"
        end
      end
    end

    class PathSegment < DynamicSegment #:nodoc:
      def interpolation_chunk(value_code = local_name)
        "\#{#{value_code}}"
      end

      def extract_value
        "#{local_name} = hash[:#{key}] && Array(hash[:#{key}]).collect { |path_component| URI.escape(path_component.to_param, ActionController::Routing::Segment::UNSAFE_PCHAR) }.to_param #{"|| #{default.inspect}" if default}"
      end

      def default
        ''
      end

      def default=(path)
        raise RoutingError, "paths cannot have non-empty default values" unless path.blank?
      end

      def match_extraction(next_capture)
        "params[:#{key}] = PathSegment::Result.new_escaped((match[#{next_capture}]#{" || " + default.inspect if default}).split('/'))#{" if match[" + next_capture + "]" if !default}"
      end

      def default_regexp_chunk
        "(.*)"
      end

      def number_of_captures
        regexp ? regexp.number_of_captures : 1
      end

      def optionality_implied?
        true
      end

      class Result < ::Array #:nodoc:
        def to_s() join '/' end
        def self.new_escaped(strings)
          new strings.collect {|str| URI.unescape str}
        end
      end
    end
    
    # The OptionalFormatSegment allows for any resource route to have an optional
    # :format, which decreases the amount of routes created by 50%.
    class OptionalFormatSegment < DynamicSegment
    
      def initialize(key = nil, options = {})
        super(:format, {:optional => true}.merge(options))            
      end
    
      def interpolation_chunk
        "." + super
      end
    
      def regexp_chunk
        '/|(\.[^/?\.]+)?'
      end
    
      def to_s
        '(.:format)?'
      end

      def extract_value
        "#{local_name} = options[:#{key}] && options[:#{key}].to_s.downcase"
      end

      #the value should not include the period (.)
      def match_extraction(next_capture)
        %[
          if (m = match[#{next_capture}])
            params[:#{key}] = URI.unescape(m.from(1))
          end
        ]
      end
    end
    
  end
end
