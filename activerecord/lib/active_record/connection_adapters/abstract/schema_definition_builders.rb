# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    module SchemaDefinitionBuilders
      # Builds a TableDefinition object.
      #
      # This definition object contains information about the table that would be created
      # if the same arguments were passed to #create_table. See #create_table for information about
      # passing a +table_name+, and other additional options that can be passed.
      def build_create_table_definition(table_name, id: :primary_key, primary_key: nil, force: nil, **options) # :nodoc:
        table_definition = create_table_definition(table_name, **extract_table_options!(options))
        table_definition.set_primary_key(table_name, id, primary_key, **options)

        yield table_definition if block_given?

        schema_creation.accept(table_definition)
        table_definition
      end
    end
  end
end
