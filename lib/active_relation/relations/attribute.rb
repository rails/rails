class Attribute
  include SqlBuilder
  
  attr_reader :relation, :name, :alias
  
  def initialize(relation, name, aliaz = nil)
    @relation, @name, @alias = relation, name, aliaz
  end
  
  def alias(aliaz = nil)
    aliaz ? Attribute.new(relation, name, aliaz) : @alias
  end
  
  def qualified_name
    "#{relation.table}.#{name}"
  end
  
  def qualify
    self.alias(qualified_name)
  end
  
  def eql?(other)
    relation == other.relation and name == other.name and self.alias == other.alias
  end

  module Predications  
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
  
  def to_sql(options = {})
    "#{quote_table_name(relation.table)}.#{quote_column_name(name)}" + (options[:use_alias] && self.alias ? " AS #{self.alias.to_s.to_sql}" : "")
  end
end