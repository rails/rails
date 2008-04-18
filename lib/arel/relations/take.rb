module Arel
  class Take < Compound
    attr_reader :taken

    def initialize(relation, taken)
      @relation, @taken = relation, taken
    end

    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      taken       == other.taken
    end
  end
end