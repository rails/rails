require 'stringio'

module ActiveRecord
  # = Active Record Schema Manager
  #
  # This class is used to dump the database schema for some connection to some
  # output format (i.e., ActiveRecord::Schema).
  class SchemaManager #:nodoc:
    class << self
      def dump(connection = ActiveRecord::Base.connection, stream = STDOUT, config = ActiveRecord::Base)
        dumper_klass = ActiveRecord::Base.schema_dumper
        dumper_klass = SchemaDumper if dumper_klass == :default

        dumper_klass.new(connection, generate_options(config)).dump(stream)
        stream
      end

      private

        def generate_options(config)
          {
            table_name_prefix: config.table_name_prefix,
            table_name_suffix: config.table_name_suffix
          }
        end
    end
  end
end
