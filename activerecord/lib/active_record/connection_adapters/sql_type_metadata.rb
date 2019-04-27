# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    class SqlTypeMetadata
      attr_reader :sql_type, :type, :limit, :precision, :scale

      def initialize(sql_type: nil, type: nil, limit: nil, precision: nil, scale: nil)
        @sql_type = sql_type
        @type = type
        @limit = limit
        @precision = precision
        @scale = scale
      end

      def ==(other)
        other.is_a?(SqlTypeMetadata) &&
          sql_type == other.sql_type &&
          type == other.type &&
          limit == other.limit &&
          precision == other.precision &&
          scale == other.scale
      end
      alias eql? ==

      def hash
        SqlTypeMetadata.hash ^
          sql_type.hash ^
          type.hash ^
          limit.hash ^
          precision.hash >> 1 ^
          scale.hash >> 2
      end
    end
  end
end
