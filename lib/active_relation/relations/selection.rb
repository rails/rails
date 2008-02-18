module ActiveRelation
  class Selection < Compound
    attr_reader :predicate

    def initialize(relation, *predicates)
      @predicate = predicates.shift
      @relation = predicates.empty?? relation : Selection.new(relation, *predicates)
    end

    def ==(other)
      self.class == other.class and
      relation   == other.relation and
      predicate  == other.predicate
    end
    
    def descend(&block)
      Selection.new(relation.descend(&block), yield(predicate))
    end
    
    protected
    def selects
      relation.send(:selects) + [predicate]
    end    
  end
end