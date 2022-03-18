# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def disable_referential_integrity # :nodoc:
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
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
            end
          rescue ActiveRecord::ActiveRecordError
          end
        end

        def all_foreign_keys_valid? # :nodoc:
          sql = <<~SQL
            do $$
              declare r record;
            BEGIN
            FOR r IN (
              SELECT FORMAT(
                'UPDATE pg_constraint SET convalidated=false WHERE conname = ''%I''; ALTER TABLE %I VALIDATE CONSTRAINT %I;',
                constraint_name,
                table_name,
                constraint_name
              ) AS constraint_check
              FROM information_schema.table_constraints WHERE constraint_type = 'FOREIGN KEY'
            )
              LOOP
                EXECUTE (r.constraint_check);
              END LOOP;
            END;
            $$;
          SQL

          begin
            transaction(requires_new: true) do
              execute(sql)
            end

            true
          rescue ActiveRecord::StatementInvalid
            false
          end
        end
      end
    end
  end
end
