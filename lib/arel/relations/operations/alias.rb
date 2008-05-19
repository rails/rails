module Arel
  class Alias < Compound
    include Recursion::BaseCase
    alias_method :==, :equal?
    
    def initialize(relation)
      @relation = relation
    end
  end
end