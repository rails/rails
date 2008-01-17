module ActiveRelation
  class Group < Compound
    attr_reader :groupings

    def initialize(relation, *groupings)
      @relation, @groupings = relation, groupings
    end

    def ==(other)
      relation == other.relation and groupings == other.groupings
    end

    def qualify
      Group.new(relation.qualify, *groupings.collect(&:qualify))
    end
  end
end