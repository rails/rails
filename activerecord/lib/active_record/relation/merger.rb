# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module ActiveRecord
  class Relation
    class HashMerger # :nodoc:
      attr_reader :relation, :hash

      def initialize(relation, hash, rewhere = nil)
        hash.assert_valid_keys(*Relation::VALUE_METHODS)

        @relation = relation
        @hash     = hash
        @rewhere  = rewhere
      end

      def merge
        Merger.new(relation, other, @rewhere).merge
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
        hash.each do |k, v|
          k = :_select if k == :select
          if Array === v
            other.public_send("#{k}!", *v)
          else
            other.public_send("#{k}!", v)
          end
        end
        other
      end
    end

    class Merger # :nodoc:
      attr_reader :relation, :values, :other

      def initialize(relation, other, rewhere = nil)
        @relation = relation
        @values   = other.values
        @other    = other
        @rewhere  = rewhere
      end

      NORMAL_VALUES = Relation::VALUE_METHODS - Relation::CLAUSE_METHODS -
                      [
                        :select, :includes, :preload, :joins, :left_outer_joins,
                        :order, :reverse_order, :lock, :create_with, :reordering
                      ]

      def merge
        NORMAL_VALUES.each do |name|
          value = values[name]
          # The unless clause is here mostly for performance reasons (since the `send` call might be moderately
          # expensive), most of the time the value is going to be `nil` or `.blank?`, the only catch is that
          # `false.blank?` returns `true`, so there needs to be an extra check so that explicit `false` values
          # don't fall through the cracks.
          unless value.nil? || (value.blank? && false != value)
            relation.public_send(:"#{name}!", *value)
          end
        end

        merge_select_values
        merge_multi_values
        merge_single_values
        merge_clauses
        merge_preloads
        merge_joins
        merge_outer_joins

        relation
      end

      private
        def merge_select_values
          return if other.select_values.empty?

          if other.klass == relation.klass
            relation.select_values |= other.select_values
          else
            relation.select_values |= other.instance_eval do
              arel_columns(select_values)
            end
          end
        end

        def merge_preloads
          return if other.preload_values.empty? && other.includes_values.empty?

          if other.klass == relation.klass
            relation.preload_values |= other.preload_values unless other.preload_values.empty?
            relation.includes_values |= other.includes_values unless other.includes_values.empty?
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
          return if other.joins_values.empty?

          if other.klass == relation.klass
            relation.joins_values |= other.joins_values
          else
            associations, others = other.joins_values.partition do |join|
              case join
              when Hash, Symbol, Array; true
              end
            end

            join_dependency = other.construct_join_dependency(
              associations, Arel::Nodes::InnerJoin
            )
            relation.joins!(join_dependency, *others)
          end
        end

        def merge_outer_joins
          return if other.left_outer_joins_values.empty?

          if other.klass == relation.klass
            relation.left_outer_joins_values |= other.left_outer_joins_values
          else
            associations, others = other.left_outer_joins_values.partition do |join|
              case join
              when Hash, Symbol, Array; true
              end
            end

            join_dependency = other.construct_join_dependency(
              associations, Arel::Nodes::OuterJoin
            )
            relation.left_outer_joins!(join_dependency, *others)
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

          where_clause = relation.where_clause.merge(other.where_clause, @rewhere)
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
