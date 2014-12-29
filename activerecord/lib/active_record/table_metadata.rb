module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :foreign_type, :foreign_key, to: :association, prefix: true

    def initialize(klass, arel_table, association = nil)
      @klass = klass
      @arel_table = arel_table
      @association = association
    end

    def resolve_column_aliases(hash)
      hash = hash.dup
      hash.keys.grep(Symbol) do |key|
        if klass.attribute_alias? key
          hash[klass.attribute_alias(key)] = hash.delete key
        end
      end
      hash
    end

    def arel_attribute(column_name)
      arel_table[column_name]
    end

    def associated_with?(association_name)
      klass && klass._reflect_on_association(association_name)
    end

    def associated_table(table_name)
      return self if table_name == arel_table.name

      association = klass._reflect_on_association(table_name)
      if association && !association.polymorphic?
        association_klass = association.klass
        arel_table = association_klass.arel_table
      else
        type_caster = TypeCaster::Connection.new(klass.connection, table_name)
        association_klass = nil
        arel_table = Arel::Table.new(table_name, type_caster: type_caster)
      end

      TableMetadata.new(association_klass, arel_table, association)
    end

    def polymorphic_association?
      association && association.polymorphic?
    end

    protected

    attr_reader :klass, :arel_table, :association
  end
end
