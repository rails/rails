class TableRelation < Relation
  attr_reader :table
  
  def initialize(table)
    @table = table
  end
  
  def attributes
    attributes_by_name.values
  end
  
  def qualify
    RenameRelation.new self, qualifications
  end
    
  protected
  def attribute(name)
    attributes_by_name[name.to_s]
  end
  
  private
  def attributes_by_name
    @attributes_by_name ||= connection.columns(table, "#{table} Columns").inject({}) do |attributes_by_name, column|
      attributes_by_name.merge(column.name => Attribute.new(self, column.name.to_sym))
    end
  end
  
  def qualifications
    attributes.zip(attributes.collect(&:qualified_name)).to_hash
  end
end