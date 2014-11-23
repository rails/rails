module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def is_superuser? # :nodoc:
          if execute('SHOW is_superuser')[0]['is_superuser'] === 'on'
            true
          else
            false
          end
        end

        def disable_referential_integrity # :nodoc:
          if is_superuser?
            execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
          else
            puts 'WARNING: Rails can\'t disable referencial integrity if the Postgres user is not a superuser. ' + \
              'It is recommended to run tests with a Postgres superuser.'
            execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
          end
          yield
        ensure
          if is_superuser?
            execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
          else
            execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER USER" }.join(";"))
          end
        end
      end
    end
  end
end
