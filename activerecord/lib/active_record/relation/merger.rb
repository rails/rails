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

      def merge
        Merger.new(relation, other).merge
      end

      # Applying values to a relation has some side effects. E.g.
      # interpolation might take place for where values. So we should
      # build a relation to merge in rather than directly merging
      # the values.
      def other
        other = Relation.create(
          relation.model,
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

      def initialize(relation, other)
        @relation = relation
        @values   = other.values_for_merge
        @other    = other
      end

      NORMAL_VALUES = (Relation::VALUE_METHODS - Relation::CLAUSE_METHODS -
                      [
                        :select, :includes, :preload, :joins, :left_outer_joins,
                        :order, :reverse_order, :lock, :create_with, :reordering, :with, :with_recursive
                      ]).freeze
      NORMAL_VALUE_BANG_METHODS = NORMAL_VALUES.index_with { |name| :"#{name}!" }.freeze

      def merge
        # Merging a relation's values into themselves is a no-op, and `unscope!`
        # would delete them while they are read.
        return relation if values.equal?(relation.values_for_merge)

        NORMAL_VALUE_BANG_METHODS.each do |name, bang_method|
          value = if name == :unscope
            other.table_name_qualified_unscope_values
          else
            values[name]
          end
          # The unless clause is here mostly for performance reasons (since the `send` call might be moderately
          # expensive), most of the time the value is going to be `nil` or `.blank?`, the only catch is that
          # `false.blank?` returns `true`, so there needs to be an extra check so that explicit `false` values
          # don't fall through the cracks.
          unless value.nil? || (value.blank? && false != value)
            relation.public_send(bang_method, *value)
          end
        end

        relation.none! if other.null_relation?

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

          if other.model == relation.model
            relation.select_values |= other.select_values
          else
            relation.select_values |= other.instance_eval do
              arel_columns(select_values)
            end
          end
        end

        def merge_preloads
          return if other.preload_values.empty? && other.includes_values.empty?

          if other.model == relation.model
            relation.preload_values |= other.preload_values unless other.preload_values.empty?
            relation.includes_values |= other.includes_values unless other.includes_values.empty?
          else
            reflection = relation.model.reflect_on_all_associations.find do |r|
              r.class_name == other.model.name
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

          if other.model == relation.model
            relation.joins_values |= other.joins_values
          else
            join_values, cte_join_nodes = foreign_join_values(other.joins_values, Arel::Nodes::InnerJoin)
            relation._joins!(join_values.concat(cte_join_nodes))
          end
        end

        def merge_outer_joins
          return if other.left_outer_joins_values.empty?

          if other.model == relation.model
            relation.left_outer_joins_values |= other.left_outer_joins_values
          else
            join_values, cte_join_nodes = foreign_join_values(other.left_outer_joins_values, Arel::Nodes::OuterJoin)
            relation._left_outer_joins!(join_values)
            # `left_outer_joins_values` only accept association joins, so the
            # joins to CTEs go along with the inner joins, which come after the
            # joins to the tables they refer to.
            relation._joins!(cte_join_nodes) unless cte_join_nodes.empty?
          end
        end

        # The association names and CTE names in the join values of a relation
        # of another model are relative to that model, so they are resolved by
        # that relation: the association names into a join dependency rooted at
        # that model, and the CTE names into join nodes to its table.
        def foreign_join_values(join_values, join_type)
          values = other.send(:classify_join_values, join_values)
          join_dependency = other.construct_join_dependency(values.association_names, join_type)
          cte_join_nodes = values.cte_names.map do |cte_name|
            other.send(:build_with_join_node, cte_name, join_type)
          end

          [[join_dependency, *values.join_dependencies, *values.nodes], cte_join_nodes]
        end

        def merge_multi_values
          if other.reordering_value
            # override any order specified in the original relation
            relation._reorder!(other.order_values.dup)
          elsif other.order_values.any?
            # merge in order_values from relation
            relation._order!(other.order_values)
          end

          relation.with_values |= other.with_values unless other.with_values.empty?
          relation.extending!(*other.extensions) unless other.extensions.empty?
        end

        def merge_single_values
          relation.lock_value ||= other.lock_value if other.lock_value
          relation.with_recursive_value = true if other.with_recursive_value

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

          no_clause_merged = [where_clause.empty?, having_clause.empty?, !replace_from_clause?].all?
          unless no_clause_merged || relation.klass.base_class == other.klass.base_class
            relation.references_values |= [*other.references_values, Arel.sql(other.table.name)]
          end
        end

        def replace_from_clause?
          relation.from_clause.empty? && !other.from_clause.empty? &&
            relation.model.base_class == other.model.base_class
        end
    end
  end
end
