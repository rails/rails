require "stringio"

module ActiveRecord
  # = Active Record Schema Dumper
  #
  # This class is used to dump the database schema for some connection to some
  # output format (i.e., ActiveRecord::Schema).
  class SchemaDumper #:nodoc:
    private_class_method :new

    ##
    # :singleton-method:
    # A list of tables which should not be dumped to the schema.
    # Acceptable values are strings as well as regexp.
    # This setting is only used if ActiveRecord::Base.schema_format == :ruby
    cattr_accessor :ignore_tables
    @@ignore_tables = []

    class << self
      def dump(connection = ActiveRecord::Base.connection, stream = STDOUT, config = ActiveRecord::Base)
        new(connection, generate_options(config)).dump(stream)
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

    def dump(stream)
      header(stream)
      extensions(stream)
      tables(stream)
      trailer(stream)
      stream
    end

    private

      def initialize(connection, options = {})
        @connection = connection
        @version = Migrator::current_version rescue nil
        @options = options
      end

      def header(stream)
        define_params = @version ? "version: #{@version}" : ""

        stream.puts <<HEADER
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(#{define_params}) do

HEADER
      end

      def trailer(stream)
        stream.puts "end"
      end

      def extensions(stream)
        return unless @connection.supports_extensions?
        extensions = @connection.extensions
        if extensions.any?
          stream.puts "  # These are extensions that must be enabled in order to support this database"
          extensions.each do |extension|
            stream.puts "  enable_extension #{extension.inspect}"
          end
          stream.puts
        end
      end

      def tables(stream)
        sorted_tables = @connection.data_sources.sort - @connection.views

        sorted_tables.each do |table_name|
          table(table_name, stream) unless ignored?(table_name)
        end

        # dump foreign keys at the end to make sure all dependent tables exist.
        if @connection.supports_foreign_keys?
          sorted_tables.each do |tbl|
            foreign_keys(tbl, stream) unless ignored?(tbl)
          end
        end
      end

      def table(table, stream)
        columns = @connection.columns(table)
        begin
          tbl = StringIO.new

          # first dump primary key column
          pk = @connection.primary_key(table)

          tbl.print "  create_table #{remove_prefix_and_suffix(table).inspect}"

          case pk
          when String
            tbl.print ", primary_key: #{pk.inspect}" unless pk == "id"
            pkcol = columns.detect { |c| c.name == pk }
            pkcolspec = @connection.column_spec_for_primary_key(pkcol)
            if pkcolspec.present?
              tbl.print ", #{format_colspec(pkcolspec)}"
            end
          when Array
            tbl.print ", primary_key: #{pk.inspect}"
          else
            tbl.print ", id: false"
          end
          tbl.print ", force: :cascade"

          table_options = @connection.table_options(table)
          if table_options.present?
            tbl.print ", #{format_options(table_options)}"
          end

          tbl.puts " do |t|"

          # then dump all non-primary key columns
          columns.each do |column|
            raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" unless @connection.valid_type?(column.type)
            next if column.name == pk
            type, colspec = @connection.column_spec(column)
            tbl.print "    t.#{type} #{column.name.inspect}"
            tbl.print ", #{format_colspec(colspec)}" if colspec.present?
            tbl.puts
          end

          indexes_in_create(table, tbl)

          tbl.puts "  end"
          tbl.puts

          tbl.rewind
          stream.print tbl.read
        rescue => e
          stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
          stream.puts "#   #{e.message}"
          stream.puts
        end

        stream
      end

      # Keep it for indexing materialized views
      def indexes(table, stream)
        if (indexes = @connection.indexes(table)).any?
          add_index_statements = indexes.map do |index|
            table_name = remove_prefix_and_suffix(index.table).inspect
            "  add_index #{([table_name] + index_parts(index)).join(', ')}"
          end

          stream.puts add_index_statements.sort.join("\n")
          stream.puts
        end
      end

      def indexes_in_create(table, stream)
        if (indexes = @connection.indexes(table)).any?
          index_statements = indexes.map do |index|
            "    t.index #{index_parts(index).join(', ')}"
          end
          stream.puts index_statements.sort.join("\n")
        end
      end

      def index_parts(index)
        index_parts = [
          index.columns.inspect,
          "name: #{index.name.inspect}",
        ]
        index_parts << "unique: true" if index.unique
        index_parts << "length: { #{format_options(index.lengths)} }" if index.lengths.present?
        index_parts << "order: { #{format_options(index.orders)} }" if index.orders.present?
        index_parts << "where: #{index.where.inspect}" if index.where
        index_parts << "using: #{index.using.inspect}" if index.using
        index_parts << "type: #{index.type.inspect}" if index.type
        index_parts << "comment: #{index.comment.inspect}" if index.comment
        index_parts
      end

      def foreign_keys(table, stream)
        if (foreign_keys = @connection.foreign_keys(table)).any?
          add_foreign_key_statements = foreign_keys.map do |foreign_key|
            parts = [
              "add_foreign_key #{remove_prefix_and_suffix(foreign_key.from_table).inspect}",
              remove_prefix_and_suffix(foreign_key.to_table).inspect,
            ]

            if foreign_key.column != @connection.foreign_key_column_for(foreign_key.to_table)
              parts << "column: #{foreign_key.column.inspect}"
            end

            if foreign_key.custom_primary_key?
              parts << "primary_key: #{foreign_key.primary_key.inspect}"
            end

            if foreign_key.name !~ /^fk_rails_[0-9a-f]{10}$/
              parts << "name: #{foreign_key.name.inspect}"
            end

            parts << "on_update: #{foreign_key.on_update.inspect}" if foreign_key.on_update
            parts << "on_delete: #{foreign_key.on_delete.inspect}" if foreign_key.on_delete

            "  #{parts.join(', ')}"
          end

          stream.puts add_foreign_key_statements.sort.join("\n")
        end
      end

      def format_colspec(colspec)
        colspec.map { |key, value| "#{key}: #{value}" }.join(", ")
      end

      def format_options(options)
        options.map { |key, value| "#{key}: #{value.inspect}" }.join(", ")
      end

      def remove_prefix_and_suffix(table)
        table.gsub(/^(#{@options[:table_name_prefix]})(.+)(#{@options[:table_name_suffix]})$/,  "\\2")
      end

      def ignored?(table_name)
        [ActiveRecord::Base.schema_migrations_table_name, ActiveRecord::Base.internal_metadata_table_name, ignore_tables].flatten.any? do |ignored|
          ignored === remove_prefix_and_suffix(table_name)
        end
      end
  end
end
