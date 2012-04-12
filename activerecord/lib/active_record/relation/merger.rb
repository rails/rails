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
        Relation::ASSOCIATION_METHODS.each do |method|
          value = other.send(:"#{method}_values")

          unless value.empty?
            relation.send("#{method}!", value)
          end
        end

        (Relation::MULTI_VALUE_METHODS - [:joins, :where, :order, :binds]).each do |method|
          value = other.send(:"#{method}_values")
          next if value.empty?

          value += relation.send(:"#{method}_values")
          relation.send :"#{method}_values=", value
        end

        relation.joins_values += other.joins_values

        merged_wheres = relation.where_values + other.where_values

        merged_binds = (relation.bind_values + other.bind_values).uniq(&:first)

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

        relation.where_values = merged_wheres
        relation.bind_values = merged_binds

        (Relation::SINGLE_VALUE_METHODS - [:lock, :create_with, :reordering]).each do |method|
          value = other.send(:"#{method}_value")
          relation.send(:"#{method}_value=", value) unless value.nil?
        end

        relation.lock_value = other.lock_value unless relation.lock_value

        unless other.create_with_value.empty?
          relation.create_with_value = (relation.create_with_value || {}).merge(other.create_with_value)
        end

        if other.reordering_value
          # override any order specified in the original relation
          relation.reordering_value = true
          relation.order_values = other.order_values
        else
          # merge in order_values from r
          relation.order_values += other.order_values
        end

        # Apply scope extension modules
        relation.send :apply_modules, other.extensions

        relation
      end
    end
  end
end
