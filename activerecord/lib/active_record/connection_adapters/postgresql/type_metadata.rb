# frozen_string_literal: true

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    class PostgreSQLTypeMetadata < DelegateClass(SqlTypeMetadata)
      undef to_yaml if method_defined?(:to_yaml)

      attr_reader :oid, :fmod, :array

      def initialize(type_metadata, oid: nil, fmod: nil)
        super(type_metadata)
        @type_metadata = type_metadata
        @oid = oid
        @fmod = fmod
        @array = /\[\]$/.match?(type_metadata.sql_type)
      end

      def sql_type
        super.gsub(/\[\]$/, "")
      end

      def ==(other)
        other.is_a?(PostgreSQLTypeMetadata) &&
          __getobj__ == other.__getobj__ &&
          oid == other.oid &&
          fmod == other.fmod &&
          array == other.array
      end
      alias eql? ==

      def hash
        PostgreSQLTypeMetadata.hash ^
          __getobj__.hash ^
          oid.hash ^
          fmod.hash ^
          array.hash
      end
    end
  end
end
