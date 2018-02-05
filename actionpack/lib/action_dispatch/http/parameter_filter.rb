# frozen_string_literal: true

require "active_support/core_ext/object/duplicable"

module ActionDispatch
  module Http
    class ParameterFilter
      FILTERED = "[FILTERED]".freeze # :nodoc:

      def initialize(filters = [])
        @filters = filters
      end

      def filter(params)
        compiled_filter.call(params)
      end

    private

      def compiled_filter
        @compiled_filter ||= CompiledFilter.compile(@filters)
      end

      class CompiledFilter # :nodoc:
        def self.compile(filters)
          return lambda { |params| params.dup } if filters.empty?

          strings, regexps, custom_filters, blocks = [], [], [], []

          filters.each do |item|
            case item
            when Proc
              blocks << item
            when Regexp
              regexps << item
            else
              if item.respond_to?(:filter?)
                custom_filters << item
              else
                strings << Regexp.escape(item.to_s)
              end
            end
          end

          deep_regexps, regexps = regexps.partition { |r| r.to_s.include?("\\.".freeze) }
          deep_strings, strings = strings.partition { |s| s.include?("\\.".freeze) }

          regexps << Regexp.new(strings.join("|".freeze), true) unless strings.empty?
          deep_regexps << Regexp.new(deep_strings.join("|".freeze), true) unless deep_strings.empty?

          new regexps, deep_regexps, custom_filters, blocks
        end

        attr_reader :regexps, :deep_regexps, :custom_filters, :blocks

        def initialize(regexps, deep_regexps, custom_filters, blocks)
          @regexps = regexps
          @deep_regexps = deep_regexps.any? ? deep_regexps : nil
          @custom_filters = custom_filters.any? ? custom_filters : nil
          @blocks = blocks
          @maintain_parents_stack = deep_regexps || custom_filters
        end

        def call(original_params, parents = [])
          filtered_params = original_params.class.new

          original_params.each do |key, value|
            parents.push(key) if @maintain_parents_stack
            if regexps.any? { |r| key =~ r }
              value = FILTERED
            elsif deep_regexps && (joined = parents.join(".")) && deep_regexps.any? { |r| joined =~ r }
              value = FILTERED
            elsif value.is_a?(Hash)
              value = call(value, parents)
            elsif value.is_a?(Array)
              value = value.map { |v| v.is_a?(Hash) ? call(v, parents) : v }
            elsif custom_filters && custom_filters.any? { |cf| cf.filter?(parents) }
              value = FILTERED
            elsif blocks.any?
              key = key.dup if key.duplicable?
              value = value.dup if value.duplicable?
              blocks.each { |b| b.call(key, value) }
            end
            parents.pop if @maintain_parents_stack

            filtered_params[key] = value
          end

          filtered_params
        end
      end
    end
  end
end
