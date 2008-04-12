module ActiveRelation
  class Skip < Compound
    attr_reader :skipped

    def initialize(relation, skipped)
      @relation, @skipped = relation, skipped
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      skipped     == other.skipped
    end
  end
end