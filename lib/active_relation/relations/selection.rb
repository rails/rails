module ActiveRelation
  class Selection < Compound
    attr_reader :predicate

    def initialize(relation, *predicates)
      predicate = predicates.shift
      @relation = predicates.empty?? relation : Selection.new(relation, *predicates)
      @predicate = predicate.bind(@relation)
    end

    def ==(other)
      self.class == other.class and
      relation   == other.relation and
      predicate  == other.predicate
    end
    
    def selects
      relation.selects + [predicate]
    end    
  end
end