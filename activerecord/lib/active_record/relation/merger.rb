module ActiveRecord
  class Relation
    class Merger
      attr_reader :relation, :other

      def initialize(relation, other)
        @relation = relation

        if other.default_scoped? && other.klass != relation.klass
          @other = other.with_default_scope
        else
          @other = other
        end
      end

      def merge
        merge_multi_values
        merge_single_values

        relation
      end

      private

      def merge_multi_values
        values = Relation::MULTI_VALUE_METHODS - [:where, :order, :bind]

        values.each do |method|
          value = other.send(:"#{method}_values")

          unless value.empty?
            relation.send("#{method}!", value)
          end
        end

        relation.where_values = merged_wheres
        relation.bind_values  = merged_binds

        if other.reordering_value
          # override any order specified in the original relation
          relation.reorder! other.order_values
        else
          # merge in order_values from r
          relation.order_values += other.order_values
        end

        # Apply scope extension modules
        relation.send :apply_modules, other.extensions
      end

      def merge_single_values
        values = Relation::SINGLE_VALUE_METHODS - [:reverse_order, :lock, :create_with, :reordering]

        values.each do |method|
          value = other.send(:"#{method}_value")
          relation.send("#{method}!", value) if value
        end

        relation.lock_value          = other.lock_value unless relation.lock_value
        relation.reverse_order_value = other.reverse_order_value

        unless other.create_with_value.empty?
          relation.create_with_value = (relation.create_with_value || {}).merge(other.create_with_value)
        end
      end

      def merged_binds
        (relation.bind_values + other.bind_values).uniq(&:first)
      end

      def merged_wheres
        merged_wheres = relation.where_values + other.where_values

        unless relation.where_values.empty?
          # Remove duplicates, last one wins.
          seen = Hash.new { |h,table| h[table] = {} }
          merged_wheres = merged_wheres.reverse.reject { |w|
            nuke = false
            if w.respond_to?(:operator) && w.operator == :==
              name              = w.left.name
              table             = w.left.relation.name
              nuke              = seen[table][name]
              seen[table][name] = true
            end
            nuke
          }.reverse
        end

        merged_wheres
      end
    end
  end
end
