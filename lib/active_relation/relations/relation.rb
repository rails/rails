class Relation
  include SqlBuilder
  
  module Iteration
    include Enumerable
    
    def each(&block)
      connection.select_all(to_s).each(&block)
    end
    
    def first
      connection.select_one(to_s)
    end
  end
  include Iteration
  
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
      RenameRelation.new(self, attribute => aliaz)
    end
    
    def insert(record)
      InsertionRelation.new(self, record)
    end
    
    def delete
      DeletionRelation.new(self)
    end
  end
  include Operations
  
  def connection
    ActiveRecord::Base.connection
  end
  
  def to_sql(options = {})
    [
      "SELECT #{attributes.collect{ |a| a.to_sql(:use_alias => true) }.join(', ')}",
      "FROM #{quote_table_name(table)}",
      (joins.to_sql(:quote => false) unless joins.blank?),
      ("WHERE #{selects.collect{|s| s.to_sql(:quote => false)}.join("\n\tAND ")}" unless selects.blank?),
      ("ORDER BY #{orders.collect(&:to_sql)}" unless orders.blank?),
      ("LIMIT #{limit.to_sql}" unless limit.blank?),
      ("OFFSET #{offset.to_sql}" unless offset.blank?)
    ].compact.join("\n")
  end
  alias_method :to_s, :to_sql
    
  protected
  def attributes; []  end
  def selects;    []  end
  def orders;     []  end
  def inserts;    []  end
  def joins;      nil end
  def limit;      nil end
  def offset;     nil end
end