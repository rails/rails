module ActiveRelation
  class Update < Compound
    attr_reader :assignments

    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments
    end

    def to_sql(strategy = nil)
      [
        "UPDATE #{table_sql} SET",
        assignments.inject([]) { |assignments, (attribute, value)| assignments << "#{attribute.to_sql} = #{value.to_sql}" }.join(" "),
        ("WHERE #{selects.collect(&:to_sql).join('\n\tAND ')}" unless selects.blank?)
      ].join("\n")
    end
    
    def ==(other)
      self.class  == other.class    and
      relation    == other.relation and
      assignments == other.assignments
    end
  end
end