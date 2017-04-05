module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def supports_disable_referential_integrity? # :nodoc:
          true
        end

        def disable_referential_integrity(&block) # :nodoc:
          if supports_disable_referential_integrity?
            if supports_alter_constraint?
              disable_referential_integrity_with_alter_constraint(&block)
            else
              disable_referential_integrity_with_disable_trigger(&block)
            end
          else
            yield
          end
        end

        private

          def disable_referential_integrity_with_alter_constraint
            tables_constraints = execute(<<-SQL).values
              SELECT table_name, constraint_name
              FROM information_schema.table_constraints
              WHERE constraint_type = 'FOREIGN KEY'
              AND is_deferrable = 'NO'
            SQL

            execute(
              tables_constraints.collect { |table, constraint|
                "ALTER TABLE #{quote_table_name(table)} ALTER CONSTRAINT #{constraint} DEFERRABLE"
              }.join(";")
            )

            begin
              transaction do
                execute("SET CONSTRAINTS ALL DEFERRED")

                yield
              end
            ensure
              execute(
                tables_constraints.collect { |table, constraint|
                  "ALTER TABLE #{quote_table_name(table)} ALTER CONSTRAINT #{constraint} NOT DEFERRABLE"
                }.join(";")
              )
            end
          end

          def disable_referential_integrity_with_disable_trigger
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

    cause: #{original_exception.try(:message)}

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
    end
  end
end
