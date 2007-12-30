class Select
  attr_reader :attributes, :tables, :predicates
  
  def initialize(*attributes)
    @attributes = attributes
  end
  
  def from(*tables)
    returning self do |select|
      @tables = tables
    end
  end
  
  def where(*predicates)
    returning self do |select|
      @predicates = predicates
    end
  end
  
  def ==(other)
    attributes == other.attributes and tables == other.tables and predicates == other.predicates
  end
end