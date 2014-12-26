module ActiveRecord
  class TableMetadata # :nodoc:
    delegate :foreign_type, :foreign_key, to: :association, prefix: true

    def initialize(klass, arel_table, association = nil)
      @klass = klass
      @arel_table = arel_table
      @association = association
    end

    def type_cast_for_database(attribute_name, value)
      return value if value.is_a?(Arel::Nodes::BindParam) || klass.nil?
      type = klass.type_for_attribute(attribute_name.to_s)
      Arel::Nodes::Quoted.new(type.type_cast_for_database(value))
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
      arel_table = Arel::Table.new(table_name)
      association = klass._reflect_on_association(table_name)
      if association && !association.polymorphic?
        klass = association.klass
      end
      TableMetadata.new(klass, arel_table, association)
    end

    def polymorphic_association?
      association && association.polymorphic?
    end

    protected

    attr_reader :klass, :arel_table, :association
  end
end
