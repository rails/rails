require 'stringio'
require 'active_support/core_ext/big_decimal'

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

    def self.dump(connection=ActiveRecord::Base.connection, stream=STDOUT)
      new(connection).dump(stream)
      stream
    end

    def dump(stream)
      header(stream)
      tables(stream)
      trailer(stream)
      stream
    end

    private

      def initialize(connection)
        @connection = connection
        @types = @connection.native_database_types
        @version = Migrator::current_version rescue nil
      end

      def header(stream)
        define_params = @version ? "version: #{@version}" : ""

        if stream.respond_to?(:external_encoding) && stream.external_encoding
          stream.puts "# encoding: #{stream.external_encoding.name}"
        end

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

      def tables(stream)
        @connection.tables.sort.each do |tbl|
          next if ['schema_migrations', ignore_tables].flatten.any? do |ignored|
            case ignored
            when String; remove_prefix_and_suffix(tbl) == ignored
            when Regexp; remove_prefix_and_suffix(tbl) =~ ignored
            else
              raise StandardError, 'ActiveRecord::SchemaDumper.ignore_tables accepts an array of String and / or Regexp values.'
            end
          end
          table(tbl, stream)
        end
      end

      def table(table, stream)
        columns = @connection.columns(table)
        begin
          tbl = StringIO.new

          # first dump primary key column
          if @connection.respond_to?(:pk_and_sequence_for)
            pk, _ = @connection.pk_and_sequence_for(table)
          elsif @connection.respond_to?(:primary_key)
            pk = @connection.primary_key(table)
          end

          tbl.print "  create_table #{remove_prefix_and_suffix(table).inspect}"
          if columns.detect { |c| c.name == pk }
            if pk != 'id'
              tbl.print %Q(, primary_key: "#{pk}")
            end
          else
            tbl.print ", id: false"
          end
          tbl.print ", force: true"
          tbl.puts " do |t|"

          # then dump all non-primary key columns
          column_specs = columns.map do |column|
            raise StandardError, "Unknown type '#{column.sql_type}' for column '#{column.name}'" unless @connection.valid_type?(column.type)
            next if column.name == pk
            @connection.column_spec(column, @types)
          end.compact

          # find all migration keys used in this table
          keys = @connection.migration_keys

          # figure out the lengths for each column based on above keys
          lengths = keys.map { |key|
            column_specs.map { |spec|
              spec[key] ? spec[key].length + 2 : 0
            }.max
          }

          # the string we're going to sprintf our values against, with standardized column widths
          format_string = lengths.map{ |len| "%-#{len}s" }

          # find the max length for the 'type' column, which is special
          type_length = column_specs.map{ |column| column[:type].length }.max

          # add column type definition to our format string
          format_string.unshift "    t.%-#{type_length}s "

          format_string *= ''

          column_specs.each do |colspec|
            values = keys.zip(lengths).map{ |key, len| colspec.key?(key) ? colspec[key] + ", " : " " * len }
            values.unshift colspec[:type]
            tbl.print((format_string % values).gsub(/,\s*$/, ''))
            tbl.puts
          end

          tbl.puts "  end"
          tbl.puts

          indexes(table, tbl)

          tbl.rewind
          stream.print tbl.read
        rescue => e
          stream.puts "# Could not dump table #{table.inspect} because of following #{e.class}"
          stream.puts "#   #{e.message}"
          stream.puts
        end

        stream
      end

      def indexes(table, stream)
        if (indexes = @connection.indexes(table)).any?
          add_index_statements = indexes.map do |index|
            statement_parts = [
              ('add_index ' + remove_prefix_and_suffix(index.table).inspect),
              index.columns.inspect,
              ('name: ' + index.name.inspect),
            ]
            statement_parts << 'unique: true' if index.unique

            index_lengths = (index.lengths || []).compact
            statement_parts << ('length: ' + Hash[index.columns.zip(index.lengths)].inspect) unless index_lengths.empty?

            index_orders = (index.orders || {})
            statement_parts << ('order: ' + index.orders.inspect) unless index_orders.empty?

            statement_parts << ('where: ' + index.where.inspect) if index.where

            '  ' + statement_parts.join(', ')
          end

          stream.puts add_index_statements.sort.join("\n")
          stream.puts
        end
      end

      def remove_prefix_and_suffix(table)
        table.gsub(/^(#{ActiveRecord::Base.table_name_prefix})(.+)(#{ActiveRecord::Base.table_name_suffix})$/,  "\\2")
      end
  end
end
