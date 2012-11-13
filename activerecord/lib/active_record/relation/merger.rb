require 'active_support/core_ext/hash/keys'

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
      attr_reader :relation, :values

      def initialize(relation, other)
        if other.default_scoped? && other.klass != relation.klass
          other = other.with_default_scope
        end

        @relation = relation
        @values   = other.values
      end

      NORMAL_VALUES = Relation::SINGLE_VALUE_METHODS +
                      Relation::MULTI_VALUE_METHODS -
                      [:where, :order, :bind, :reverse_order, :lock, :create_with, :reordering, :from] # :nodoc:

      def normal_values
        NORMAL_VALUES
      end

      def merge
        normal_values.each do |name|
          value = values[name]
          relation.send("#{name}!", *value) unless value.blank?
        end

        merge_multi_values
        merge_single_values

        relation
      end

      private

      def merge_multi_values
        relation.where_values = merged_wheres
        relation.bind_values  = merged_binds

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

      def merged_binds
        if values[:bind]
          (relation.bind_values + values[:bind]).uniq(&:first)
        else
          relation.bind_values
        end
      end

      def merged_wheres
        if values[:where]
          merged_wheres = relation.where_values + values[:where]

          unless relation.where_values.empty?
            # Remove equalities with duplicated left-hand. Last one wins.
            seen = {}
            merged_wheres = merged_wheres.reverse.reject { |w|
              nuke = false
              if w.respond_to?(:operator) && w.operator == :==
                nuke         = seen[w.left]
                seen[w.left] = true
              end
              nuke
            }.reverse
          end

          merged_wheres
        else
          relation.where_values
        end
      end
    end
  end
end
