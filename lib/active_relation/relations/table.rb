module ActiveRelation
  class Table < Relation
    attr_reader :name

    def initialize(name)
      @name = name.to_s
    end

    def attributes
      @attributes ||= columns.collect do |column|
        Attribute.new(self, column.name.to_sym)
      end
    end

    def qualify
      Rename.new self, qualifications
    end
    
    def prefix_for(attribute)
      self[attribute] and name
    end
    
    def column_for(attribute)
      self[attribute] and columns.detect { |c| c.name == attribute.name }
    end
    
    def ==(other)
      self.class == other.class and
      name       == other.name
    end
        
    def columns
      @columns ||= connection.columns(name, "#{name} Columns")
    end

    protected    
    def table_sql
      "#{quote_table_name(name)}"
    end
    
    private
    def qualifications
      attributes.zip(attributes.collect(&:qualified_name)).to_hash
    end
  end
end