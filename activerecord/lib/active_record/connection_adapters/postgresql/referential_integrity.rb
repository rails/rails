module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module ReferentialIntegrity
        def supports_disable_referential_integrity? #:nodoc:
          true
        end

        def disable_referential_integrity #:nodoc:
          if supports_disable_referential_integrity?
            begin
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
            rescue
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
            end
          end
          yield
        ensure
          if supports_disable_referential_integrity?
            begin
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL" }.join(";"))
            rescue
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER USER" }.join(";"))
            end
          end
        end
      end
    end
  end
end
