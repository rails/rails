module ActiveRecord
  module ConnectionAdapters
    # Mysql2-specific extensions to column definitions in a table.
    class Mysql2AdapterColumn < Column # :nodoc:
      attr_reader :collation, :strict, :extra

      def initialize(name, default, cast_type, sql_type = nil, null = true, collation = nil, strict = false, extra = "")
        @strict = strict
        @collation = collation
        @extra = extra
        super(name, default, cast_type, sql_type, null)
        assert_valid_default(default)
        extract_default
      end

      def extract_default
        if blob_or_text_column?
          @default = null || strict ? nil : ''
        elsif missing_default_forged_as_empty_string?(@default)
          @default = nil
        end
      end

      def has_default?
        return false if blob_or_text_column? # MySQL forbids defaults on blob and text columns
        super
      end

      def blob_or_text_column?
        sql_type =~ /blob/i || type == :text
      end

      def case_sensitive?
        collation && !collation.match(/_ci$/)
      end

      private
        # MySQL misreports NOT NULL column default when none is given.
        # We can't detect this for columns which may have a legitimate ''
        # default (string) but we can for others (integer, datetime, boolean,
        # and the rest).
        #
        # Test whether the column has default '', is not null, and is not
        # a type allowing default ''.
        def missing_default_forged_as_empty_string?(default)
          type != :string && !null && default == ''
        end

        def assert_valid_default(default)
          if blob_or_text_column? && default.present?
            raise ArgumentError, "#{type} columns cannot have a default value: #{default.inspect}"
          end
        end
    end
  end
end
