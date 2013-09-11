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
        other = Relation.new(relation.klass, relation.table)
        hash.each { |k, v|
          if k == :joins
            if Hash === v
              other.joins!(v)
            else
              other.joins!(*v)
            end
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
        if other.default_scoped? && other.klass != relation.klass
          other = other.with_default_scope
        end

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
          relation.send("#{name}!", *value) unless value.nil? || (value.blank? && false != value)
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

          join_dependency.join_associations.each do |association|
            @relation = association.join_relation(relation)
          end
        end
      end

      def merge_multi_values
        lhs_wheres = relation.where_values
        rhs_wheres = values[:where] || []
        lhs_binds  = relation.bind_values
        rhs_binds  = values[:bind] || []

        removed, kept = partition_overwrites(lhs_wheres, rhs_wheres)

        relation.where_values = kept + rhs_wheres
        relation.bind_values  = filter_binds(lhs_binds, removed) + rhs_binds

        if values[:reordering]
          # override any order specified in the original relation
          relation.reorder! values[:order]
        elsif values[:order]
          # merge in order_values from r
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
        set = Set.new removed_wheres.map { |x| x.left.name }
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
