class Attribute
  attr_reader :relation, :name, :aliaz
  
  def initialize(relation, name, aliaz = nil)
    @relation, @name, @aliaz = relation, name, aliaz
  end
  
  def aliazz(aliaz)
    Attribute.new(relation, name, aliaz)
  end
  
  def qualified_name
    "#{relation.table}.#{name}"
  end
  
  def qualify
    aliazz(qualified_name)
  end

  module Predications
    def eql?(other)
      relation == other.relation and name == other.name and aliaz == other.aliaz
    end
  
    def ==(other)
      EqualityPredicate.new(self, other)
    end
  
    def <(other)
      LessThanPredicate.new(self, other)
    end
  
    def <=(other)
      LessThanOrEqualToPredicate.new(self, other)
    end
  
    def >(other)
      GreaterThanPredicate.new(self, other)
    end
  
    def >=(other)
      GreaterThanOrEqualToPredicate.new(self, other)
    end
  
    def =~(regexp)
      MatchPredicate.new(self, regexp)
    end
  end
  include Predications
  
  def to_sql(builder = SelectsBuilder.new)
    builder.call do
      column relation.table, name, aliaz
    end
  end
end