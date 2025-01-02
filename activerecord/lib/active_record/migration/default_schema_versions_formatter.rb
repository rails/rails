# frozen_string_literal: true

module ActiveRecord
  class Migration
    # This class is used by the schema dumper to format versions information.
    #
    # The class receives the current +connection+ when initialized.
    class DefaultSchemaVersionsFormatter # :nodoc:
      def initialize(connection)
        @connection = connection
      end

      def format(versions)
        sm_table = connection.quote_table_name(connection.pool.schema_migration.table_name)

        if versions.is_a?(Array)
          sql = +"INSERT INTO #{sm_table} (version) VALUES\n"
          sql << versions.reverse.map { |v| "(#{connection.quote(v)})" }.join(",\n")
          sql << ";"
          sql
        else
          "INSERT INTO #{sm_table} (version) VALUES (#{connection.quote(versions)});"
        end
      end

      private
        attr_reader :connection
    end
  end
end
