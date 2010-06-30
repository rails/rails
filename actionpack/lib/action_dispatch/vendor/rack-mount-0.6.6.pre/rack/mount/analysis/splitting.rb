require 'rack/mount/utils'

module Rack::Mount
  module Analysis
    class Splitting < Frequency
      NULL = "\0".freeze

      class Key < Struct.new(:method, :index, :separators)
        def self.split(value, separator_pattern)
          keys = value.split(separator_pattern)
          keys.shift if keys[0] == ''
          keys << NULL
          keys
        end

        def call(cache, obj)
          (cache[method] ||= self.class.split(obj.send(method), separators))[index]
        end

        def call_source(cache, obj)
          "(#{cache}[:#{method}] ||= Analysis::Splitting::Key.split(#{obj}.#{method}, #{separators.inspect}))[#{index}]"
        end

        def inspect
          "#{method}[#{index}]"
        end
      end

      def clear
        @boundaries = {}
        super
      end

      def <<(key)
        super
        key.each_pair do |k, v|
          analyze_capture_boundaries(v, @boundaries[k] ||= Histogram.new)
        end
      end

      def separators(key)
        (@boundaries[key].keys_in_upper_quartile + ['/']).uniq
      end

      def process_key(requirements, method, requirement)
        separators = separators(method)
        if requirement.is_a?(Regexp) && separators.any?
          generate_split_keys(requirement, separators).each_with_index do |value, index|
            requirements[Key.new(method, index, Regexp.union(*separators))] = value
          end
        else
          super
        end
      end

      private
        def analyze_capture_boundaries(regexp, boundaries) #:nodoc:
          return boundaries unless regexp.is_a?(Regexp)

          parts = Utils.parse_regexp(regexp)
          parts.each_with_index do |part, index|
            if part.is_a?(Regin::Group)
              if index > 0
                previous = parts[index-1]
                if previous.is_a?(Regin::Character) && previous.literal?
                  boundaries << previous.to_s
                end
              end

              if inside = part.expression[0]
                if inside.is_a?(Regin::Character) && inside.literal?
                  boundaries << inside.to_s
                end
              end

              if index < parts.length
                following = parts[index+1]
                if following.is_a?(Regin::Character) && following.literal?
                  boundaries << following.to_s
                end
              end
            end
          end

          boundaries
        end

        def generate_split_keys(regexp, separators) #:nodoc:
          segments = []
          buf = nil
          parts = Utils.parse_regexp(regexp)
          parts.each_with_index do |part, index|
            case part
            when Regin::Anchor
              if part.value == '$' || part.value == '\Z'
                segments << join_buffer(buf, regexp) if buf
                segments << NULL
                buf = nil
                break
              end
            when Regin::CharacterClass
              break if separators.any? { |s| part.include?(s) }
              buf = nil
              segments << part.to_regexp(true)
            when Regin::Character
              if separators.any? { |s| part.include?(s) }
                segments << join_buffer(buf, regexp) if buf
                peek = parts[index+1]
                if peek.is_a?(Regin::Character) && separators.include?(peek.value)
                  segments << ''
                end
                buf = nil
              else
                buf ||= Regin::Expression.new([])
                buf += [part]
              end
            when Regin::Group
              if part.quantifier == '?'
                value = part.expression.first
                if separators.any? { |s| value.include?(s) }
                  segments << join_buffer(buf, regexp) if buf
                  buf = nil
                end
                break
              elsif part.quantifier == nil
                break if separators.any? { |s| part.include?(s) }
                buf = nil
                segments << part.to_regexp(true)
              else
                break
              end
            else
              break
            end

            if index + 1 == parts.size
              segments << join_buffer(buf, regexp) if buf
              buf = nil
              break
            end
          end

          while segments.length > 0 && (segments.last.nil? || segments.last == '')
            segments.pop
          end

          segments
        end

        def join_buffer(parts, regexp)
          if parts.literal?
            parts.to_s
          else
            parts.to_regexp(true)
          end
        end
    end
  end
end
