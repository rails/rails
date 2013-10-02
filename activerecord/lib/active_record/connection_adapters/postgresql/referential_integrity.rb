module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module ReferentialIntegrity
        def supports_disable_referential_integrity? #:nodoc:
          true
        end

        def create_referential_integrity_savepoint
          # create_savepoint if open_transactions > 0
          execute("SAVEPOINT disable_referential_integrity") if open_transactions > 0
        end

        def rollback_to_referential_integrity_savepoint
          # rollback_to_savepoint if open_transactions > 0
          execute("ROLLBACK TO SAVEPOINT disable_referential_integrity") if open_transactions > 0
        end

        def release_referential_integrity_savepoint
          # release_savepoint if open_transactions > 0
          execute("RELEASE SAVEPOINT disable_referential_integrity") if open_transactions > 0
        end

        def disable_referential_integrity #:nodoc:
          @referential_integrity_depth = 0 unless instance_variable_defined?(:@referential_integrity_depth)
          if supports_disable_referential_integrity?
            create_referential_integrity_savepoint
            begin
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
              have_superuser_privs = true
            rescue
              rollback_to_referential_integrity_savepoint
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
              have_superuser_privs = false
            end
            release_referential_integrity_savepoint
            @referential_integrity_depth += 1

            create_referential_integrity_savepoint
            begin
              yield
            ensure
              begin
                release_referential_integrity_savepoint
              rescue ActiveRecord::StatementInvalid
                rollback_to_referential_integrity_savepoint
                release_referential_integrity_savepoint
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
