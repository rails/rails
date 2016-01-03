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
          attributes_for_hash == other.attributes_for_hash
      end
      alias eql? ==

      def hash
        attributes_for_hash.hash
      end

      protected

      def attributes_for_hash
        [self.class, sql_type, type, limit, precision, scale]
      end
    end
  end
end
