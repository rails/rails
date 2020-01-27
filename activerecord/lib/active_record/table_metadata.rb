# frozen_string_literal: true

module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :foreign_type, :foreign_key, :join_primary_key, :join_foreign_key, to: :association, prefix: true

    def initialize(klass, arel_table, association = nil, types = klass)
      @klass = klass
      @types = types
      @arel_table = arel_table
      @association = association
    end

    def resolve_column_aliases(hash)
      new_hash = hash.dup
      hash.each_key do |key|
        if key.is_a?(Symbol) && new_key = klass.attribute_aliases[key.to_s]
          new_hash[new_key] = new_hash.delete(key)
        end
      end
      new_hash
    end

    def arel_attribute(column_name)
      if klass
        klass.arel_attribute(column_name, arel_table)
      else
        arel_table[column_name]
      end
    end

    def type(column_name)
      types.type_for_attribute(column_name)
    end

    def has_column?(column_name)
      klass && klass.columns_hash.key?(column_name.to_s)
    end

    def associated_with?(association_name)
      klass && klass._reflect_on_association(association_name)
    end

    def associated_table(table_name)
      association = klass._reflect_on_association(table_name) || klass._reflect_on_association(table_name.to_s.singularize)

      if !association && table_name == arel_table.name
        self
      elsif association && !association.polymorphic?
        association_klass = association.klass
        arel_table = association_klass.arel_table.alias(table_name)
        TableMetadata.new(association_klass, arel_table, association)
      else
        type_caster = TypeCaster::Connection.new(klass, table_name)
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
        TableMetadata.new(nil, arel_table, association, type_caster)
      end
    end

    def associated_predicate_builder(table_name)
      associated_table(table_name).predicate_builder
    end

    def polymorphic_association?
      association && association.polymorphic?
    end

    def aggregated_with?(aggregation_name)
      klass && reflect_on_aggregation(aggregation_name)
    end

    def reflect_on_aggregation(aggregation_name)
      klass.reflect_on_aggregation(aggregation_name)
    end

    protected
      def predicate_builder
        if klass
          predicate_builder = klass.predicate_builder.dup
          predicate_builder.instance_variable_set(:@table, self)
          predicate_builder
        else
          PredicateBuilder.new(self)
        end
      end

    private
      attr_reader :klass, :types, :arel_table, :association
  end
end
