# frozen_string_literal: true

module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :join_primary_key, :join_primary_type, :join_foreign_key, :join_foreign_type, to: :reflection

    def initialize(klass, arel_table, reflection = nil)
      @klass = klass
      @arel_table = arel_table
      @reflection = reflection
    end

    def primary_key
      klass&.primary_key
    end

    def type(column_name)
      arel_table.type_for_attribute(column_name)
    end

    def has_column?(column_name)
      klass&.columns_hash&.key?(column_name)
    end

    def associated_with?(table_name)
      if reflection = klass&._reflect_on_association(table_name)
        reflection
      elsif ActiveRecord.allow_deprecated_singular_associations_name && reflection = klass&._reflect_on_association(table_name.singularize)
        ActiveRecord.deprecator.warn(<<~MSG)
          Referring to a singular association (e.g. `#{reflection.name}`) by its plural name (e.g. `#{reflection.plural_name}`) is deprecated.

          To convert this deprecation warning to an error and enable more performant behavior, set config.active_record.allow_deprecated_singular_associations_name = false.
        MSG
        reflection
      end
    end

    def associated_table(table_name)
      reflection = klass._reflect_on_association(table_name) || klass._reflect_on_association(table_name.singularize)

      if !reflection && table_name == arel_table.name
        return self
      end

      if reflection
        association_klass = reflection.klass unless reflection.polymorphic?
      elsif block_given?
        association_klass = yield table_name
      end

      if association_klass
        arel_table = association_klass.arel_table
        arel_table = arel_table.alias(table_name) if arel_table.name != table_name
        TableMetadata.new(association_klass, arel_table, reflection)
      else
        type_caster = TypeCaster::Connection.new(klass, table_name)
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
        TableMetadata.new(nil, arel_table, reflection)
      end
    end

    def polymorphic_association?
      reflection&.polymorphic?
    end

    def polymorphic_name_association
      reflection&.polymorphic_name
    end

    def through_association?
      reflection&.through_reflection?
    end

    def reflect_on_aggregation(aggregation_name)
      klass&.reflect_on_aggregation(aggregation_name)
    end
    alias :aggregated_with? :reflect_on_aggregation

    def predicate_builder
      if klass
        predicate_builder = klass.predicate_builder.dup
        predicate_builder.instance_variable_set(:@table, self)
        predicate_builder
      else
        PredicateBuilder.new(self)
      end
    end

    attr_reader :arel_table

    private
      attr_reader :klass, :reflection
  end
end
