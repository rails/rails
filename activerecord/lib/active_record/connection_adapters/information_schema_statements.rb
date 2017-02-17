module ActiveRecord
  module ConnectionAdapters
    module InformationSchemaStatements
      class Name
        attr_reader :schema, :identifier

        def initialize(schema, identifier)
          @schema = schema
          @identifier = identifier
        end
      end

      # Returns true if table exists.
      # If the schema is not specified as part of +name+ then it will only find tables within
      # the current schema search path (regardless of permissions to access tables in other schemas)
      def table_exists?(name)
        select_values(<<-SQL, "SCHEMA").any?
          SELECT table_name
          FROM information_schema.tables
          WHERE table_name = #{quote(name.identifier)}
          AND table_type = 'BASE TABLE'
          AND table_schema = #{name.schema ? quote(name.schema) : "ANY (current_schemas(false))"}
        SQL
      end
    end
  end
end
