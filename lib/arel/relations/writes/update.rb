module Arel
  class Update < Compound
    attributes :relation, :assignments
    deriving :==

    def initialize(relation, assignments)
      @relation, @assignments = relation, assignments
    end

    def to_sql(formatter = nil)
      [
        "UPDATE #{table_sql} SET",
        map_assignments,
        ("WHERE #{wheres.map(&:to_sql).join('\n\tAND ')}"  unless wheres.blank?  ),
        ("LIMIT #{taken}"                                      unless taken.blank?    )
      ].join("\n")
    end

    def call(connection = engine)
      connection.update(to_sql)
    end

    def map_assignments
      assignments.collect do |attribute, value|
        attribute.respond_to?(:name) ?
          "#{engine.quote_column_name(attribute.name)} = #{attribute.format(value)}" : attribute
      end.join(",\n")
    end
  end
end
