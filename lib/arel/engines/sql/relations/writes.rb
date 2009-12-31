module Arel
  class Deletion < Compound
    def to_sql
      build_query \
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank? ),
        ("LIMIT #{taken}"                                     unless taken.blank?  )
    end
  end

  class Insert < Compound
    def to_sql
      insertion_attributes_values_sql = if record.is_a?(Value)
        record.value
      else
        attributes = record.keys.sort_by do |attribute|
          attribute.name.to_s
        end

        first = attributes.collect do |key|
          engine.quote_column_name(key.name)
        end.join(', ')

        second = attributes.collect do |key|
          key.format(record[key])
        end.join(', ')

        build_query "(#{first})", "VALUES (#{second})"
      end

      build_query \
        "INSERT",
        "INTO #{table_sql}",
        insertion_attributes_values_sql
    end
  end

  class Update < Compound
    def to_sql
      build_query \
        "UPDATE #{table_sql} SET",
        assignment_sql,
        build_update_conditions_sql
    end

  protected

    def assignment_sql
      if assignments.respond_to?(:collect)
        attributes = assignments.keys.sort_by do |attribute|
          attribute.name.to_s
        end

        attributes.map do |attribute|
          value = assignments[attribute]
          "#{engine.quote_column_name(attribute.name)} = #{attribute.format(value)}"
        end.join(", ")
      else
        assignments.value
      end
    end

    def build_update_conditions_sql
      conditions = ""
      conditions << " WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank?
      conditions << " ORDER BY #{order_clauses.join(', ')}" unless orders.blank?

      unless taken.blank?
        conditions << " LIMIT #{taken}"

        if engine.adapter_name != "MySQL"
          begin
            quote_primary_key = engine.quote_column_name(table.name.classify.constantize.primary_key)
          rescue NameError
            quote_primary_key = engine.quote_column_name("id")
          end

          conditions =  "WHERE #{quote_primary_key} IN (SELECT #{quote_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions})"
        end
      end

      conditions
    end
  end
end
