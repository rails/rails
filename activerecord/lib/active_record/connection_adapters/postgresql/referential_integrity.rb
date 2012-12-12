module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLAdapter < AbstractAdapter
      module ReferentialIntegrity
        def supports_disable_referential_integrity? #:nodoc:
          true
        end

        def disable_referential_integrity #:nodoc:
          all_disabled = []
          user_disabled = []
          if supports_disable_referential_integrity? then
            tables.each do |name|
              begin
                execute "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER ALL;"
                all_disabled << name
              rescue
                execute "ALTER TABLE #{quote_table_name(name)} DISABLE TRIGGER USER;"
                user_disabled << name
              end
            end
          end
          yield
        ensure
          if supports_disable_referential_integrity? then
            execute((
                all_disabled.collect{|name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER ALL"} + 
                user_disabled.collect{|name| "ALTER TABLE #{quote_table_name(name)} ENABLE TRIGGER USER"}
              ).join(";"))
          end
        end
      end
    end
  end
end
