# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    class SqlTypeMetadata
      include Deduplicable

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
        [
          SqlTypeMetadata,
          @sql_type,
          @type,
          @limit,
          @precision,
          @scale,
        ].hash
      end

      def as_schema_json
        { "sql_type" => sql_type, "type" => type, "limit" => limit, "precision" => precision, "scale" => scale }
      end

      def init_from_schema_json(coder, references)
        @sql_type = coder["sql_type"]
        @type = coder["type"]&.to_sym
        @limit = coder["limit"]
        @precision = coder["precision"]
        @scale = coder["scale"]
      end

      private
        def deduplicated
          @sql_type = -sql_type
          super
        end
    end
  end
end
