module ActiveRecord
  module ConnectionAdapters
    class PostgreSQLTypeMetadata < DelegateClass(SqlTypeMetadata)
      attr_reader :oid, :fmod, :array

      def initialize(type_metadata, oid: nil, fmod: nil)
        super(type_metadata)
        @type_metadata = type_metadata
        @oid = oid
        @fmod = fmod
        @array = /\[\]$/ === type_metadata.sql_type
      end

      def sql_type
        super.gsub(/\[\]$/, "".freeze)
      end

      def ==(other)
        other.is_a?(PostgreSQLTypeMetadata) &&
          attributes_for_hash == other.attributes_for_hash
      end
      alias eql? ==

      def hash
        attributes_for_hash.hash
      end

      protected

      def attributes_for_hash
        [self.class, @type_metadata, oid, fmod]
      end
    end
  end
end
