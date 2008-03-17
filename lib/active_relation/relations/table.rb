module ActiveRelation
  class Table < Relation
    cattr_accessor :engine
    attr_reader :name, :engine
    
    hash_on :name
    
    def initialize(name, engine = Table.engine)
      @name, @engine = name.to_s, engine
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
      self[attribute] and columns.detect { |c| c.name == attribute.name.to_s }
    end
    
    def ==(other)
      self.class == other.class and
      name       == other.name
    end
    
    def columns
      @columns ||= engine.columns(name, "#{name} Columns")
    end
    
    def descend
      yield self
    end
    
    def reset
      @attributes = @columns = nil
    end

    def table_sql
      "#{engine.quote_table_name(name)}"
    end
    
    private
    def qualifications
      attributes.zip(attributes.collect(&:qualified_name)).to_hash
    end
  end
end