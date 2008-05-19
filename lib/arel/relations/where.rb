module Arel
  class Where < Compound
    attr_reader :predicate

    def initialize(relation, *predicates)
      predicate = predicates.shift
      @relation = predicates.empty?? relation : Where.new(relation, *predicates)
      @predicate = predicate.bind(@relation)
    end

    def wheres
      @wheres ||= (relation.wheres + [predicate]).collect { |p| p.bind(self) }
    end    

    def ==(other)
      Where     === other          and
      relation  ==  other.relation and
      predicate ==  other.predicate
    end
  end
end