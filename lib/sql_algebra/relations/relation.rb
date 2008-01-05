class Relation
  module Operations
    def <=>(other)
      InnerJoinOperation.new(self, other)
    end
  
    def <<(other)
      LeftOuterJoinOperation.new(self, other)
    end
  
    def [](index)
      case index
      when Symbol
        attribute(index)
      when Range
        RangeRelation.new(self, index)
      end
    end
  
    def include?(attribute)
      RelationInclusionPredicate.new(attribute, self)
    end
  
    def select(*predicates)
      SelectionRelation.new(self, *predicates)
    end
  
    def project(*attributes)
      ProjectionRelation.new(self, *attributes)
    end
  
    def order(*attributes)
      OrderRelation.new(self, *attributes)
    end
    
    def rename(attribute, aliaz)
      RenameRelation.new(self, attribute, aliaz)
    end
  end
  include Operations
  
  def connection
    ActiveRecord::Base.connection
  end
  
  def to_sql(builder = SelectBuilder.new)
    builder.call do
      select do
        attributes.each { |a| a.to_sql(self) }
      end
      from table do
        joins.each { |j| j.to_sql(self) }
      end
      where do
        selects.each { |s| s.to_sql(self) }
      end
      order_by do
        orders.each { |o| o.to_sql(self) }
      end
    end
  end
  
  protected
  def attributes; [] end
  def joins;      [] end
  def selects;    [] end
  def orders;     [] end
            
end