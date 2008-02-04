module ActiveRelation
  class Table < Relation
    attr_reader :name

    def initialize(name)
      @name = name
    end

    def attributes
      attributes_by_name.values
    end

    def qualify
      Rename.new self, qualifications
    end
    
    def prefix_for(attribute)
      name
    end
    
    def aliased_prefix_for(attribute)
      name
    end
    
    protected    
    def attribute_for_name(name)
      attributes_by_name[name.to_s]
    end
    
    def table_sql
      "#{quote_table_name(name)}"
    end

    private
    def attributes_by_name
      @attributes_by_name ||= connection.columns(name, "#{name} Columns").inject({}) do |attributes_by_name, column|
        attributes_by_name.merge(column.name => Attribute.new(self, column.name.to_sym))
      end
    end

    def qualifications
      attributes.zip(attributes.collect(&:qualified_name)).to_hash
    end
  end
end