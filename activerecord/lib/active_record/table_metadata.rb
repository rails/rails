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
      return self if table_name == arel_table.name

      arel_table = Arel::Table.new(table_name)
      association = klass._reflect_on_association(table_name)
      if association && !association.polymorphic?
        association_klass = association.klass
      end

      if association
        TableMetadata.new(association_klass, arel_table, association)
      else
        ConnectionAdapterTable.new(klass.connection, arel_table)
      end
    end

    def polymorphic_association?
      association && association.polymorphic?
    end

    protected

    attr_reader :klass, :arel_table, :association
  end

  # FIXME: We want to get rid of this class. The connection adapter does not
  # have sufficient knowledge about types, as they could be provided by or
  # overriden by the ActiveRecord::Base subclass. The case where you reach this
  # class is if you do a query like:
  #
  #     Liquid.joins(molecules: :electrons)
  #       .where("molecules.name" => "something", "electrons.name" => "something")
  #
  # Since we don't know that we can get to electrons through molecules
  class ConnectionAdapterTable # :nodoc:
    def initialize(connection, arel_table)
      @connection = connection
      @arel_table = arel_table
    end

    def type_cast_for_database(attribute_name, value)
      return value if value.is_a?(Arel::Nodes::BindParam)
      type = type_for(attribute_name)
      Arel::Nodes::Quoted.new(type.type_cast_for_database(value))
    end

    def resolve_column_aliases(hash)
      hash
    end

    def arel_attribute(column_name)
      arel_table[column_name]
    end

    def associated_with?(*)
      false
    end

    def associated_table(table_name)
      arel_table = Arel::Table.new(table_name)
      ConnectionAdapterTable.new(klass.connection, arel_table)
    end

    def polymorphic_association?
      false
    end

    protected

    attr_reader :connection, :arel_table

    private

    def type_for(attribute_name)
      if connection.schema_cache.table_exists?(arel_table.name)
        column_for(attribute_name).cast_type
      else
        Type::Value.new
      end
    end

    def column_for(attribute_name)
      connection.schema_cache.columns_hash(arel_table.name)[attribute_name.to_s]
    end
  end
end
