# frozen_string_literal: true

require "active_support/core_ext/enumerable"

module ActiveRecord
  class InsertRows # :nodoc:
    attr_reader :model, :connection, :inserts, :columns, :returning

    class << self
      def execute(model, ...)
        model.with_connection do |c|
          new(model, c, ...).execute
        end
      end
    end

    def initialize(model, connection, inserts, columns:, returning: nil)
      @model = model
      @connection = connection

      columns = columns.map(&:to_s)
      duplicated_columns = columns.tally.select { |_, c| c > 1 }.keys
      if duplicated_columns.any?
        raise ArgumentError, "Duplicate columns are not allowed, found columns: #{duplicated_columns.join(', ')}"
      end

      @columns = columns.to_set
      @inserts = inserts

      @returning = returning

      disallow_raw_sql!(returning)

      @returning = (connection.supports_insert_returning? ? primary_keys : false) if @returning.nil?
      @returning = false if @returning == []

      ensure_valid_options_for_connection!
    end

    def execute
      return ActiveRecord::Result.empty if inserts.empty?

      message = +"#{model} Bulk Insert"
      connection.exec_insert_all to_sql, message
    end

    def primary_keys
      Array(@model.schema_cache.primary_keys(model.table_name))
    end

    private
      def ensure_valid_options_for_connection!
        if returning && !connection.supports_insert_returning?
          raise ArgumentError, "#{connection.class} does not support :returning"
        end
      end

      def to_sql
        connection.build_insert_sql(ActiveRecord::InsertRows::Builder.new(self))
      end

      def disallow_raw_sql!(value)
        return if !value.is_a?(String) || Arel.arel_node?(value)

        raise ArgumentError, "Dangerous query method (method whose arguments are used as raw " \
                             "SQL) called: #{value}. " \
                             "Known-safe values can be passed " \
                             "by wrapping them in Arel.sql()."
      end

      class Builder # :nodoc:
        attr_reader :model

        delegate :columns, to: :insert_all

        def initialize(insert_all)
          @insert_all, @model, @connection = insert_all, insert_all.model, insert_all.connection
        end

        def into
          "INTO #{model.quoted_table_name} (#{columns_list})"
        end

        def values_list
          insert_all.inserts.each_with_index do |row, index|
            next if row.length == columns.length

            raise ArgumentError, "Number of columns (#{row.length}) does not match number of keys (#{columns.length}) at index #{index}"
          end
          values_list = insert_all.inserts

          connection.visitor.compile(Arel::Nodes::ValuesList.new(values_list))
        end

        def returning
          return unless insert_all.returning

          if insert_all.returning.is_a?(String)
            insert_all.returning
          else
            Array(insert_all.returning).map do |attribute|
              quote_column(attribute)
            end.join(",")
          end
        end

        def raw_update_sql
          insert_all.update_sql
        end

        def keys
          columns
        end

        def skip_duplicates?
          false
        end

        def update_duplicates?
          false
        end

        alias raw_update_sql? raw_update_sql

        private
          attr_reader :connection, :insert_all

          def columns_list
            insert_all.columns.map { |column| quote_column(column) }.join(",")
          end

          def quote_column(column)
            connection.quote_column_name(column)
          end
      end
  end
end
