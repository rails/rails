module Arel
  module SqlCompiler
    class GenericCompiler
      attr_reader :relation

      def initialize(relation)
        @relation = relation
      end

      def select_sql
        query = build_query \
          "SELECT     #{select_clauses.join(', ')}",
          "FROM       #{from_clauses}",
          (joins(self)                                   unless joins(self).blank? ),
          ("WHERE     #{where_clauses.join(' AND ')}"    unless wheres.blank?      ),
          ("GROUP BY  #{group_clauses.join(', ')}"       unless groupings.blank?   ),
          ("HAVING    #{having_clauses.join(' AND ')}"      unless havings.blank?     ),
          ("ORDER BY  #{order_clauses.join(', ')}"       unless orders.blank?      )
          engine.add_limit_offset!(query,{ :limit => taken, :offset => skipped }) if taken || skipped
          query << " #{locked}" unless locked.blank?
          query
      end

      def delete_sql
        build_query \
          "DELETE",
          "FROM #{table_sql}",
          ("WHERE #{wheres.collect(&:to_sql).join(' AND ')}" unless wheres.blank? ),
          (add_limit_on_delete(taken)                        unless taken.blank?  )
      end

      def add_limit_on_delete(taken)
        "LIMIT #{taken}"
      end

      def insert_sql(include_returning = true)
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

      def supports_insert_with_returning?
        false
      end

      def update_sql
        build_query \
          "UPDATE #{table_sql} SET",
          assignment_sql,
          build_update_conditions_sql
      end

    protected
      def method_missing(method, *args, &block)
        relation.send(method, *args, &block)
      end

      def build_query(*parts)
        parts.compact.join(" ")
      end

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
          conditions = limited_update_conditions(conditions, taken)
        end

        conditions
      end

      def limited_update_conditions(conditions, taken)
        conditions << " LIMIT #{taken}"
        quoted_primary_key = engine.quote_column_name(primary_key)
        "WHERE #{quoted_primary_key} IN (SELECT #{quoted_primary_key} FROM #{engine.connection.quote_table_name table.name} #{conditions})"
      end

    end

  end
end
