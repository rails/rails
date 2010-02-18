module Arel
  class Deletion < Compound
    def to_sql
      build_query \
        "DELETE",
        "FROM #{table_sql}",
        ("WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank? ),
        ("LIMIT #{taken}"                                  unless taken.blank?  )
    end
  end

  class Insert < Compound
    def to_sql(include_returning = true)
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
        insertion_attributes_values_sql,
        ("RETURNING #{engine.quote_column_name(primary_key)}" if include_returning && compiler.supports_insert_with_returning?)
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

        conditions = compiler.limited_update_conditions(conditions)
      end

      conditions
    end
  end
end
