module ActiveRelation
  class Update < Compound
    attr_reader :assignments

    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments
    end

    def to_sql(strategy = nil)
      [
        "UPDATE #{table_sql} SET",
        assignments.inject("") do |assignments, (attribute, value)| 
          assignments << " #{attribute.to_sql} = #{value.to_sql}"
        end,
        ("WHERE #{selects.collect(&:to_sql).join('\n\tAND ')}" unless selects.blank?)
      ].join("\n")
    end
    
    def call(connection = engine.connection)
      connection.update(to_sql)
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      assignments == other.assignments
    end
  end
end