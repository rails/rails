module Arel
  class Grouping < Compound
    attr_reader :groupings

    def initialize(relation, *groupings)
      @relation, @groupings = relation, groupings.collect { |g| g.bind(relation) }
    end

    def ==(other)
      self.class  == other.class      and
      relation    == other.relation   and
      groupings   == other.groupings
    end

    def aggregation?
      true
    end
    
    def table_sql(formatter = Sql::TableReference.new(self))
      to_sql(formatter)
    end
    
    def name
      table.name + '_aggregation'
    end
  end
end