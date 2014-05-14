require 'active_support/core_ext/hash/keys'
require "set"

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
        other = Relation.create(relation.klass, relation.table)
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

      NORMAL_VALUES = Relation::SINGLE_VALUE_METHODS +
                      Relation::MULTI_VALUE_METHODS -
                      [:joins, :where, :order, :bind, :reverse_order, :lock, :create_with, :reordering, :from] # :nodoc:

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
        merge_joins

        relation
      end

      private

      def merge_joins
        return if values[:joins].blank?

        if other.klass == relation.klass
          relation.joins!(*values[:joins])
        else
          joins_dependency, rest = values[:joins].partition do |join|
            case join
            when Hash, Symbol, Array
              true
            else
              false
            end
          end

          join_dependency = ActiveRecord::Associations::JoinDependency.new(other.klass,
                                                                           joins_dependency,
                                                                           [])
          relation.joins! rest

          @relation = relation.joins join_dependency
        end
      end

      def merge_multi_values
        lhs_wheres = relation.where_values
        rhs_wheres = values[:where] || []

        lhs_binds  = relation.bind_values
        rhs_binds  = values[:bind] || []

        removed, kept = partition_overwrites(lhs_wheres, rhs_wheres)

        where_values = kept + rhs_wheres
        bind_values  = filter_binds(lhs_binds, removed) + rhs_binds

        conn = relation.klass.connection
        bv_index = 0
        where_values.map! do |node|
          if Arel::Nodes::Equality === node && Arel::Nodes::BindParam === node.right
            substitute = conn.substitute_at(bind_values[bv_index].first, bv_index)
            bv_index += 1
            Arel::Nodes::Equality.new(node.left, substitute)
          else
            node
          end
        end

        relation.where_values = where_values
        relation.bind_values  = bind_values

        if values[:reordering]
          # override any order specified in the original relation
          relation.reorder! values[:order]
        elsif values[:order]
          # merge in order_values from relation
          relation.order! values[:order]
        end

        relation.extend(*values[:extending]) unless values[:extending].blank?
      end

      def merge_single_values
        relation.from_value          = values[:from] unless relation.from_value
        relation.lock_value          = values[:lock] unless relation.lock_value
        relation.reverse_order_value = values[:reverse_order]

        unless values[:create_with].blank?
          relation.create_with_value = (relation.create_with_value || {}).merge(values[:create_with])
        end
      end

      def filter_binds(lhs_binds, removed_wheres)
        return lhs_binds if removed_wheres.empty?

        set = Set.new removed_wheres.map { |x| x.left.name.to_s }
        lhs_binds.dup.delete_if { |col,_| set.include? col.name }
      end

      # Remove equalities from the existing relation with a LHS which is
      # present in the relation being merged in.
      # returns [things_to_remove, things_to_keep]
      def partition_overwrites(lhs_wheres, rhs_wheres)
        if lhs_wheres.empty? || rhs_wheres.empty?
          return [[], lhs_wheres]
        end

        nodes = rhs_wheres.find_all do |w|
          w.respond_to?(:operator) && w.operator == :==
        end
        seen = Set.new(nodes) { |node| node.left }

        lhs_wheres.partition do |w|
          w.respond_to?(:operator) && w.operator == :== && seen.include?(w.left)
        end
      end
    end
  end
end
