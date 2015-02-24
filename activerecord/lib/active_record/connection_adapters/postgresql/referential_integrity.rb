module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ReferentialIntegrity # :nodoc:
        def supports_disable_referential_integrity? # :nodoc:
          true
        end

        def disable_referential_integrity # :nodoc:
          original_exception = nil
          if supports_disable_referential_integrity?
            begin
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL" }.join(";"))
            rescue => e
              original_exception = e
              execute(tables.collect { |name| "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER" }.join(";"))
            end
          end

          begin
            yield
          rescue ActiveRecord::InvalidForeignKey
            warn "WARNING: Rails can't disable referential integrity: #{original_exception.message}"
            raise
          end

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
