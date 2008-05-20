module Arel
  class Group < Compound
    attributes :relation, :groupings
    deriving :==

    def initialize(relation, *groupings, &block)
      @relation = relation
      @groupings = (groupings + (block_given?? [yield(self)] : [])).collect { |g| g.bind(relation) }
    end

    def externalizable?
      true
    end
  end
end