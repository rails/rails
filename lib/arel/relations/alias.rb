module Arel
  class Alias < Compound
    attr_reader :alias
    
    def initialize(relation)
      @relation = relation
    end
    
    def ==(other)
      self.equal? other
    end
  end
end