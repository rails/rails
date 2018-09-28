# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActiveRecord
  class Relation
    class HashMerger # :nodoc:
      attr_reader :relation, :hash

      def initialize(relation, hash)
        hash.assert_valid_keys(*Relation::VALUE_METHODS)

        @relation = relation
        @hash     = hash
      end

      def merge #:nodoc:
        Merger.new(relation, other).merge
      end

      # Applying values to a relation has some side effects. E.g.
      # interpolation might take place for where values. So we should
      # build a relation to merge in rather than directly merging
      # the values.
      def other
        other = Relation.create(
          relation.klass,
          table: relation.table,
          predicate_builder: relation.predicate_builder
        )
        hash.each { |k, v|
          if k == :joins
            if Hash === v
              other.joins!(v)
            else
              other.joins!(*v)
            end
          elsif k == :select
            other._select!(v)
          else
            other.send("#{k}!", v)
          end
        }
        other
      end
    end

    class Merger # :nodoc:
      attr_reader :relation, :values, :other

      def initialize(relation, other)
        @relation = relation
        @values   = other.values
        @other    = other
      end

      NORMAL_VALUES = Relation::VALUE_METHODS -
                      Relation::CLAUSE_METHODS -
                      [:includes, :preload, :joins, :left_outer_joins, :order, :reverse_order, :lock, :create_with, :reordering] # :nodoc:

      def normal_values
        NORMAL_VALUES
      end

      def merge
        normal_values.each do |name|
          value = values[name]
          # The unless clause is here mostly for performance reasons (since the `send` call might be moderately
          # expensive), most of the time the value is going to be `nil` or `.blank?`, the only catch is that
          # `false.blank?` returns `true`, so there needs to be an extra check so that explicit `false` values
          # don't fall through the cracks.
          unless value.nil? || (value.blank? && false != value)
            if name == :select
              relation._select!(*value)
            else
              relation.send("#{name}!", *value)
            end
          end
        end

        merge_multi_values
        merge_single_values
        merge_clauses
        merge_preloads
        merge_joins
        merge_outer_joins

        relation
      end

      private

        def merge_preloads
          return if other.preload_values.empty? && other.includes_values.empty?

          if other.klass == relation.klass
            relation.preload!(*other.preload_values) unless other.preload_values.empty?
            relation.includes!(other.includes_values) unless other.includes_values.empty?
          else
            reflection = relation.klass.reflect_on_all_associations.find do |r|
              r.class_name == other.klass.name
            end || return

            unless other.preload_values.empty?
              relation.preload! reflection.name => other.preload_values
            end

            unless other.includes_values.empty?
              relation.includes! reflection.name => other.includes_values
            end
          end
        end

        def merge_joins
          return if other.joins_values.blank?

          if other.klass == relation.klass
            relation.joins!(*other.joins_values)
          else
            joins_dependency = other.joins_values.map do |join|
              case join
              when Hash, Symbol, Array
                ActiveRecord::Associations::JoinDependency.new(
                  other.klass, other.table, join
                )
              else
                join
              end
            end

            relation.joins!(*joins_dependency)
          end
        end

        def merge_outer_joins
          return if other.left_outer_joins_values.blank?

          if other.klass == relation.klass
            relation.left_outer_joins!(*other.left_outer_joins_values)
          else
            joins_dependency = other.left_outer_joins_values.map do |join|
              case join
              when Hash, Symbol, Array
                ActiveRecord::Associations::JoinDependency.new(
                  other.klass, other.table, join
                )
              else
                join
              end
            end

            relation.left_outer_joins!(*joins_dependency)
          end
        end

        def merge_multi_values
          if other.reordering_value
            # override any order specified in the original relation
            relation.reorder!(*other.order_values)
          elsif other.order_values.any?
            # merge in order_values from relation
            relation.order!(*other.order_values)
          end

          extensions = other.extensions - relation.extensions
          relation.extending!(*extensions) if extensions.any?
        end

        def merge_single_values
          relation.lock_value ||= other.lock_value if other.lock_value

          unless other.create_with_value.blank?
            relation.create_with_value = (relation.create_with_value || {}).merge(other.create_with_value)
          end
        end

        def merge_clauses
          relation.from_clause = other.from_clause if replace_from_clause?

          where_clause = relation.where_clause.merge(other.where_clause)
          relation.where_clause = where_clause unless where_clause.empty?

          having_clause = relation.having_clause.merge(other.having_clause)
          relation.having_clause = having_clause unless having_clause.empty?
        end

        def replace_from_clause?
          relation.from_clause.empty? && !other.from_clause.empty? &&
            relation.klass.base_class == other.klass.base_class
        end
    end
  end
end
