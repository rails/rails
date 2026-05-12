# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity # :nodoc:
          original_exception = nil
          table_names = schema_qualified_tables

          begin
            transaction(requires_new: true) do
              execute(table_names.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
            end
          rescue ActiveRecord::ActiveRecordError => e
            original_exception = e
          end

          begin
            yield
          rescue ActiveRecord::InvalidForeignKey => e
            warn <<-WARNING
WARNING: Rails was not able to disable referential integrity.

This is most likely caused due to missing permissions.
Rails needs superuser privileges to disable referential integrity.

    cause: #{original_exception&.message}

            WARNING
            raise e
          end

          begin
            transaction(requires_new: true) do
              execute(table_names.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
            end
          rescue ActiveRecord::ActiveRecordError
          end
        end

        def check_all_foreign_keys_valid! # :nodoc:
          sql = <<~SQL
            do $$
              declare r record;
            BEGIN
            FOR r IN (
              SELECT FORMAT(
                'UPDATE pg_catalog.pg_constraint SET convalidated=false WHERE conname = ''%1$I'' AND connamespace::regnamespace = ''%2$I''::regnamespace; ALTER TABLE %2$I.%3$I VALIDATE CONSTRAINT %1$I;',
                constraint_name,
                table_schema,
                table_name
              ) AS constraint_check
              FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY'
            )
              LOOP
                EXECUTE (r.constraint_check);
              END LOOP;
            END;
            $$;
          SQL

          transaction(requires_new: true) do
            execute(sql)
          end
        end

        private
          # Like `data_source_sql`, but returns schema-qualified names so that tables with the same name in multiple
          # schemas in the search_path are handled correctly.
          def schema_qualified_tables
            scope = quoted_scope(nil, type: "BASE TABLE")
            sql = +"SELECT n.nspname || '.' || c.relname FROM pg_class c "
            sql << "LEFT JOIN pg_namespace n ON n.oid = c.relnamespace"
            sql << " WHERE n.nspname = #{scope[:schema]}"
            sql << " AND c.relkind IN (#{scope[:type] || "'r','p'"})"
            query_values(sql)
          end
      end
    end
  end
end
