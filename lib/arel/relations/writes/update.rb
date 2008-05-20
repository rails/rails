module Arel
  class Update < Compound
    attributes :relation, :assignments
    deriving :==
    
    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments.bind(relation)
    end

    def to_sql(formatter = nil)
      [
        "UPDATE #{table_sql} SET",
        assignments.collect do |attribute, value|
          "#{value.format(attribute)} = #{attribute.format(value)}"
        end.join(",\n"),
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}"  unless wheres.blank?  ),
        ("LIMIT #{taken}"                                      unless taken.blank?    )
      ].join("\n")
    end
    
    def call(connection = engine.connection)
      connection.update(to_sql)
    end
  end
end