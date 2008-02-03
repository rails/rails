module ActiveRelation
  class Aggregation < Compound
    attr_reader :expressions, :groupings
    alias_method :attributes, :expressions

    def initialize(relation, options)
      @relation, @expressions, @groupings = relation, options[:expressions], options[:groupings]
    end

    def ==(other)
      relation == other.relation and groupings == other.groupings and expressions == other.expressions
    end

    def qualify
      Aggregation.new(relation.qualify, :expressions => expressions.collect(&:qualify), :groupings => groupings.collect(&:qualify))
    end
    
    protected
    def aggregation?
      true
    end
    
    def attribute_for_expression(expression)
      expression.relation == self ? expression : (e = @expressions.detect { |e| e == expression }) && e.substitute(self)
    end
  end
end