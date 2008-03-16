module ActiveRelation
  class Aggregation < Compound
    attr_reader :expressions, :groupings

    def initialize(relation, options)
      @relation, @expressions, @groupings = relation, options[:expressions], options[:groupings]
    end

    def ==(other)
      self.class  == other.class      and
      relation    == other.relation   and
      groupings   == other.groupings  and
      expressions == other.expressions
    end

    def attributes
      expressions.collect { |e| e.bind(self) }
    end
    
    def aggregation?
      true
    end
    
    def descend(&block)
      Aggregation.new(relation.descend(&block), :expressions => expressions.collect(&block), :groupings => groupings.collect(&block))
    end
  end
end