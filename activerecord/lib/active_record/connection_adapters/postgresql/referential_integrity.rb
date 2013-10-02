module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module ReferentialIntegrity
        def supports_disable_referential_integrity? #:nodoc:
          true
        end

        def disable_referential_integrity #:nodoc:
          @referential_integrity_depth = 0 unless instance_variable_defined?(:@referential_integrity_depth)

          if supports_disable_referential_integrity?
            referential_integrity_savepoint_name = "disable_referential_integrity_#{@referential_integrity_depth}"

            create_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
            begin
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
              have_superuser_privs = true
            rescue
              rollback_to_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
              have_superuser_privs = false
            end
            release_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
            @referential_integrity_depth += 1

            create_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
            begin
              yield
            ensure
              begin
                release_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
              rescue ActiveRecord::StatementInvalid
                rollback_to_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
                release_savepoint(referential_integrity_savepoint_name) if open_transactions > 0
              end
              @referential_integrity_depth -= 1
              if @referential_integrity_depth <= 0
                execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER #{have_superuser_privs ? 'ALL' : 'USER'}" }.join(";"))
              end
            end
          else
            yield
          end
        end
      end
    end
  end
end
