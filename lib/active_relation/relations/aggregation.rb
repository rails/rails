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
  end
end