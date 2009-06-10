module Arel
  class Deletion < Compound
    def to_sql(formatter = nil)
      build_query \
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}" unless wheres.blank? ),
        ("LIMIT #{taken}"                                     unless taken.blank?  )
    end
  end

  class Insert < Compound
    def to_sql(formatter = nil)
      build_query \
        "INSERT",
        "INTO #{table_sql}",
        "(#{record.keys.collect { |key| engine.quote_column_name(key.name) }.join(', ')})",
        "VALUES (#{record.collect { |key, value| key.format(value) }.join(', ')})"
    end
  end

  class Update < Compound
    def to_sql(formatter = nil)
      build_query \
        "UPDATE #{table_sql} SET",
        assignment_sql,
        ("WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}"  unless wheres.blank? ),
        ("LIMIT #{taken}"                                      unless taken.blank?  )
    end

  protected

    def assignment_sql
      if assignments.respond_to?(:collect)
        assignments.collect do |attribute, value|
          "#{engine.quote_column_name(attribute.name)} = #{attribute.format(value)}"
        end.join(",\n")
      else
        assignments.value
      end
    end
  end
end
