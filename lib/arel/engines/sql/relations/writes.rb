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
        build_update_conditions_sql
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

    def build_update_conditions_sql
      conditions = ""
      conditions << " WHERE #{wheres.collect(&:to_sql).join('\n\tAND ')}" unless wheres.blank?
      conditions << " ORDER BY #{order_clauses.join(', ')}" unless orders.blank?

      unless taken.blank?
        conditions << " LIMIT #{taken}"

        if engine.adapter_name != "MySQL"
          quote_primary_key = engine.quote_column_name(table.name.classify.constantize.primary_key)
          conditions =  "WHERE #{quote_primary_key} IN (SELECT #{quote_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions})"
        end
      end

      conditions
    end
  end
end
