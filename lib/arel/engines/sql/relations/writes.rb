module Arel
  class Deletion < Compound
    def to_sql(formatter = nil)
      [
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}" unless wheres.blank?  ),
        ("LIMIT #{taken}"                                     unless taken.blank?    ),
      ].compact.join("\n")
    end
  end

  class Insert < Compound
    def to_sql(formatter = nil)
      [
        "INSERT",
        "INTO #{table_sql}",
        "(#{record.keys.collect { |key| engine.quote_column_name(key.name) }.join(', ')})",
        "VALUES (#{record.collect { |key, value| key.format(value) }.join(', ')})"
      ].join("\n")
    end
  end

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
