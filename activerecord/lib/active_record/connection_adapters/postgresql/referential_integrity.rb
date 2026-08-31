# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity(&block) # :nodoc:
          if supports_enforced_foreign_keys?
            toggle_foreign_key_enforcement(current_schemas_only: true, &block)
          else
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
              warn <<~WARNING
                WARNING: Rails was not able to disable referential integrity.

                This is most likely caused due to missing permissions.
                The user must be superuser to execute DISABLE TRIGGER ALL.

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
        end

        def check_all_foreign_keys_valid! # :nodoc:
          if supports_enforced_foreign_keys?
            toggle_foreign_key_enforcement
          else
            sql = <<~SQL
              do $$
                declare r record;
              BEGIN
              FOR r IN (
                SELECT FORMAT(
                  'UPDATE pg_catalog.pg_constraint SET convalidated=false WHERE conname = ''%1$I'' AND connamespace::regnamespace = ''%2$I''::regnamespace AND conrelid::regclass = ''%3$I''::regclass; ALTER TABLE %2$I.%3$I VALIDATE CONSTRAINT %1$I;',
                  constraint_name,
                  table_schema,
                  table_name
                ) AS constraint_check
                FROM information_schema.table_constraints tc
                WHERE tc.constraint_type = 'FOREIGN KEY'
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
        end

        private
          # Like #data_source_sql, but returns schema qualified names, so that tables sharing
          # a name across several schemas on the search path are all covered.
          def schema_qualified_tables
            scope = quoted_scope(nil, type: "BASE TABLE")
            sql = +"SELECT n.nspname || '.' || c.relname FROM pg_class c "
            sql << "LEFT JOIN pg_namespace n ON n.oid = c.relnamespace"
            sql << " WHERE n.nspname = #{scope[:schema]}"
            sql << " AND c.relkind IN (#{scope[:type]})"
            query_values(sql)
          end

          # conparentid = 0: a partition's child copy can't be ALTERed; the parent's ALTER cascades
          def enforced_foreign_keys(current_schemas_only: false)
            query_all(<<~SQL)
              SELECT n.nspname AS schema_name, t.relname AS table_name, c.conname AS constraint_name
              FROM pg_constraint c
              JOIN pg_class t ON c.conrelid = t.oid
              JOIN pg_namespace n ON c.connamespace = n.oid
              WHERE c.contype = 'f'
                AND c.conenforced = true
                AND c.conparentid = 0
                AND pg_catalog.pg_has_role(t.relowner, 'USAGE')
                #{"AND n.nspname = ANY (current_schemas(false))" if current_schemas_only}
            SQL
          end

          def toggle_foreign_key_enforcement(current_schemas_only: false)
            fks = enforced_foreign_keys(current_schemas_only: current_schemas_only)

            transaction(requires_new: true) do
              fks.each { |fk| set_foreign_key_enforcement(fk, enforced: false) }

              yield if block_given?

              fks.each { |fk| set_foreign_key_enforcement(fk, enforced: true) }
            end
          end

          def set_foreign_key_enforcement(fk, enforced:)
            table = "#{quote_column_name(fk["schema_name"])}.#{quote_column_name(fk["table_name"])}"
            execute("ALTER TABLE #{table} ALTER CONSTRAINT #{quote_column_name(fk["constraint_name"])} " \
                    "#{enforced ? "ENFORCED" : "NOT ENFORCED"}")
          end
      end
    end
  end
end
