require 'rack/mount/utils'

module Rack::Mount
  class GeneratableRegexp < Regexp #:nodoc:
    class DynamicSegment #:nodoc:
      attr_reader :name, :requirement

      def initialize(name, requirement)
        @name, @requirement = name.to_sym, requirement
        freeze
      end

      def ==(obj)
        @name == obj.name && @requirement == obj.requirement
      end

      def =~(str)
        @requirement =~ str
      end

      def to_hash
        { @name => @requirement }
      end

      def inspect
        "/(?<#{@name}>#{@requirement.source})/"
      end
    end

    module InstanceMethods
      def self.extended(obj)
        obj.segments
      end

      def defaults=(defaults)
        @required_captures = nil
        @required_params = nil
        @required_defaults = nil
        @defaults = defaults
      end

      def defaults
        @defaults ||= {}
      end

      def generatable?
        segments.any?
      end

      def generate(params = {}, recall = {}, options = {})
        return nil unless generatable?

        merged = recall.merge(params)
        return nil unless required_params.all? { |p| merged.include?(p) }
        return nil unless required_defaults.all? { |k, v| merged[k] == v }

        generate_from_segments(segments, params, merged, options)
      end

      def segments
        @segments ||= begin
          defaults
          segments = []
          catch(:halt) do
            expression = Utils.parse_regexp(self)
            segments = parse_segments(expression)
          end
          segments
        end
      end

      def captures
        segments.flatten.find_all { |s| s.is_a?(DynamicSegment) }
      end

      def required_captures
        @required_captures ||= segments.find_all { |s|
          s.is_a?(DynamicSegment) && !@defaults.include?(s.name)
        }.freeze
      end

      def required_params
        @required_params ||= required_captures.map { |s| s.name }.freeze
      end

      def required_defaults
        @required_defaults ||= begin
          required_defaults = @defaults.dup
          captures.inject({}) { |h, s| h.merge!(s.to_hash) }.keys.each { |name|
            required_defaults.delete(name)
          }
          required_defaults
        end
      end

      def freeze
        segments
        captures
        required_captures
        required_params
        required_defaults
        super
      end

      private
        def parse_segments(segments)
          s = []
          segments.each_with_index do |part, index|
            case part
            when Regin::Anchor
              # ignore
            when Regin::Character
              throw :halt unless part.literal?

              if s.last.is_a?(String)
                s.last << part.value.dup
              else
                s << part.value.dup
              end
            when Regin::Group
              if part.name
                s << DynamicSegment.new(part.name, part.expression.to_regexp(true))
              else
                s << parse_segments(part.expression)
              end
            when Regin::Expression
              return parse_segments(part)
            else
              throw :halt
            end
          end

          s
        end

        EMPTY_STRING = ''.freeze

        def generate_from_segments(segments, params, merged, options, optional = false)
          if optional
            return EMPTY_STRING if segments.all? { |s| s.is_a?(String) }
            return EMPTY_STRING unless segments.flatten.any? { |s|
              params.has_key?(s.name) if s.is_a?(DynamicSegment)
            }
            return EMPTY_STRING if segments.any? { |segment|
              if segment.is_a?(DynamicSegment)
                value = merged[segment.name] || @defaults[segment.name]
                value = parameterize(segment.name, value, options)

                merged_value  = parameterize(segment.name, merged[segment.name], options)
                default_value = parameterize(segment.name, @defaults[segment.name], options)

                if value.nil? || segment !~ value
                  true
                elsif merged_value == default_value
                  # Nasty control flow
                  return :clear_remaining_segments
                else
                  false
                end
              end
            }
          end

          generated = segments.map do |segment|
            case segment
            when String
              segment
            when DynamicSegment
              value = params[segment.name] || merged[segment.name] || @defaults[segment.name]
              value = parameterize(segment.name, value, options)
              if value && segment =~ value.to_s
                value
              else
                return
              end
            when Array
              value = generate_from_segments(segment, params, merged, options, true)
              if value == :clear_remaining_segments
                segment.each { |s| params.delete(s.name) if s.is_a?(DynamicSegment) }
                EMPTY_STRING
              elsif value.nil?
                EMPTY_STRING
              else
                value
              end
            end
          end

          # Delete any used items from the params
          segments.each { |s| params.delete(s.name) if s.is_a?(DynamicSegment) }

          generated.join
        end

        def parameterize(name, value, options)
          if block = options[:parameterize]
            block.call(name, value)
          else
            value
          end
        end
    end
    include InstanceMethods

    def initialize(regexp)
      super
      segments
    end
  end
end
