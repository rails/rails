# frozen_string_literal: true

module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :foreign_type, :foreign_key, :join_primary_key, :join_foreign_key, to: :association, prefix: true

    def initialize(klass, arel_table, association = nil)
      @klass = klass
      @arel_table = arel_table
      @association = association
    end

    def resolve_column_aliases(hash)
      new_hash = hash.dup
      hash.each do |key, _|
        if (key.is_a?(Symbol)) && klass.attribute_alias?(key)
          new_hash[klass.attribute_alias(key)] = new_hash.delete(key)
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
      if klass
        klass.type_for_attribute(column_name)
      else
        Type.default_value
      end
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
        return self
      elsif association && !association.polymorphic?
        association_klass = association.klass
        arel_table = association_klass.arel_table.alias(table_name)
      else
        type_caster = TypeCaster::Connection.new(klass, table_name)
        association_klass = nil
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
      end

      TableMetadata.new(association_klass, arel_table, association)
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

    # TODO Change this to private once we've dropped Ruby 2.2 support.
    # Workaround for Ruby 2.2 "private attribute?" warning.
    protected

      attr_reader :klass, :arel_table, :association
  end
end
