module ActiveRelation
  class Update < Writing
    attr_reader :assignments

    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments.bind(relation)
    end

    def to_sql(formatter = nil)
      [
        "UPDATE #{table_sql} SET",
        assignments.collect do |attribute, value|
          "#{value.format(attribute)} = #{attribute.format(value)}"
        end.join("\n"),
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