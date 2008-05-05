module Arel
  class Alias < Compound
    include Recursion::BaseCase
    
    def initialize(relation)
      @relation = relation
    end
    
    def ==(other)
      equal? other
    end
  end
end