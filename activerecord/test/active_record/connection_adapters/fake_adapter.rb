# frozen_string_literal: true

module ActiveRecord
  module ConnectionHandling
    def fake_connection(config)
      ConnectionAdapters::FakeAdapter.new nil, logger
    end
  end

  module ConnectionAdapters
    class FakeAdapter < AbstractAdapter
      attr_accessor :data_sources, :primary_keys

      @columns = Hash.new { |h, k| h[k] = [] }
      class << self
        attr_reader :columns
      end

      def initialize(connection, logger)
        super
        @data_sources = []
        @primary_keys = {}
        @columns      = self.class.columns
      end

      def primary_key(table)
        @primary_keys[table] || "id"
      end

      def merge_column(table_name, name, sql_type = nil, options = {})
        @columns[table_name] << ActiveRecord::ConnectionAdapters::Column.new(
          name.to_s,
          options[:default],
          fetch_type_metadata(sql_type),
          options[:null],
        )
      end

      def columns(table_name)
        @columns[table_name]
      end

      def data_source_exists?(*)
        true
      end

      def active?
        true
      end
    end
  end
end
