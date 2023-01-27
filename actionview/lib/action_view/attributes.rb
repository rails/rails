# frozen_string_literal: true

require "set"

module ActionView
  class Attributes < DelegateClass(Hash) # :nodoc:
    cattr_accessor :token_lists, default: Set.new

    def initialize(view_context, value = {}, &serializer)
      super(value)
      @view_context = view_context
      @serializer = serializer
    end

    def dup
      Attributes.new(@view_context, super, &@serializer)
    end

    def merge(values, &block)
      dup.merge!(values, &block)
    end
    alias_method :deep_merge, :merge

    def merge!(values, &block)
      merge_conflicts = block || proc do |name, left, right|
        if token_list?(name)
          token_list(left, right)
        elsif left.respond_to?(:merge) && right.respond_to?(:to_h)
          deep_merge_token_lists left, right, namespace: name
        else
          right
        end
      end

      super(values, &merge_conflicts)

      self
    end
    alias_method :deep_merge!, :merge!

    def to_s
      if @serializer
        yield_self(&@serializer)
      else
        super
      end
    end

    private
      delegate :token_list, to: :@view_context

      def deep_merge_token_lists(attributes, overrides, namespace:)
        attributes.merge(overrides.to_h) do |name, left, right|
          if token_list?("#{namespace}-#{name.to_s.dasherize}")
            token_list(left, right)
          else
            right
          end
        end
      end

      def token_list?(name)
        name.in?(token_lists) || name.to_s.in?(token_lists) || matches_token_list_pattern?(name.to_s)
      end

      def matches_token_list_pattern?(name)
        token_list_patterns.any? { |pattern| pattern.match?(name.to_s.dasherize) }
      end

      def token_list_patterns
        token_lists.select { |token_list| token_list.is_a?(Regexp) }
      end
  end
end
