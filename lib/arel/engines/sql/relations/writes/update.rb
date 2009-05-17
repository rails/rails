module Arel
  class Update < Compound
    def to_sql(formatter = nil)
      [
        "UPDATE #{table_sql} SET",
        assignments.collect do |attribute, value|
          "#{engine.quote_column_name(attribute.name)} = #{attribute.format(value)}"
        end.join(",\n"),
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}"  unless wheres.blank?  ),
        ("LIMIT #{taken}"                                      unless taken.blank?    )
      ].join("\n")
    end
  end
end