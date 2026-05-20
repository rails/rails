# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity # :nodoc:
          if supports_enforced_foreign_keys?
            # Only toggle FKs that are currently `ENFORCED`; leave `NOT ENFORCED` ones unchanged.
            # `conparentid = 0` excludes constraints inherited from a partitioned parent —
            # `ALTER CONSTRAINT` must be issued on the parent and is propagated to partitions.
            enforced_fks = query_all(<<~SQL)
              SELECT n.nspname AS schema_name, t.relname AS table_name, c.conname AS constraint_name
              FROM pg_constraint c
              JOIN pg_class t ON c.conrelid = t.oid
              JOIN pg_namespace n ON c.connamespace = n.oid
              WHERE c.contype = 'f'
                AND c.conenforced = true
                AND c.conparentid = 0
                AND n.nspname = ANY (current_schemas(false))
            SQL

            transaction(requires_new: true) do
              enforced_fks.each do |fk|
                execute("ALTER TABLE #{quote_table_name(fk["schema_name"])}.#{quote_table_name(fk["table_name"])} " \
                        "ALTER CONSTRAINT #{quote_column_name(fk["constraint_name"])} NOT ENFORCED")
              end

              yield

              enforced_fks.each do |fk|
                execute("ALTER TABLE #{quote_table_name(fk["schema_name"])}.#{quote_table_name(fk["table_name"])} " \
                        "ALTER CONSTRAINT #{quote_column_name(fk["constraint_name"])} ENFORCED")
              end
            end
          else
            original_exception = nil

            begin
              transaction(requires_new: true) do
                execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
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
                execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
              end
            rescue ActiveRecord::ActiveRecordError
            end
          end
        end

        def check_all_foreign_keys_valid! # :nodoc:
          # Skip `NOT ENFORCED` constraints (PG 18.4+): `VALIDATE CONSTRAINT` cannot be
          # applied to them and raises an error.
          if supports_enforced_foreign_keys?
            enforced_join = <<~SQL
              JOIN pg_catalog.pg_constraint c
                ON c.conname = tc.constraint_name
               AND c.conenforced = true
              JOIN pg_catalog.pg_class cls ON cls.oid = c.conrelid
               AND cls.relname = tc.table_name
              JOIN pg_catalog.pg_namespace ns ON ns.oid = cls.relnamespace
               AND ns.nspname = tc.table_schema
               AND ns.nspname = tc.constraint_schema
            SQL
          end

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
              FROM information_schema.table_constraints tc
              #{enforced_join}
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
    end
  end
end
