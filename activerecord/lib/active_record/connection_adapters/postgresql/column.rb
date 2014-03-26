module ActiveRecord
  module ConnectionAdapters
    # PostgreSQL-specific extensions to column definitions in a table.
    class PostgreSQLColumn < Column #:nodoc:
      attr_accessor :array

      def initialize(name, default, oid_type, sql_type = nil, null = true)
        @oid_type = oid_type
        default_value     = self.class.extract_value_from_default(default)

        if sql_type =~ /\[\]$/
          @array = true
          super(name, default_value, sql_type[0..sql_type.length - 3], null)
        else
          @array = false
          super(name, default_value, sql_type, null)
        end

        @default_function = default if has_default_function?(default_value, default)
      end

      def number?
        !array && super
      end

      def text?
        !array && super
      end

      # :stopdoc:
      class << self
        include ConnectionAdapters::PostgreSQLColumn::Cast
        include ConnectionAdapters::PostgreSQLColumn::ArrayParser
        attr_accessor :money_precision
      end
      # :startdoc:

      # Extracts the value from a PostgreSQL column default definition.
      def self.extract_value_from_default(default)
        # This is a performance optimization for Ruby 1.9.2 in development.
        # If the value is nil, we return nil straight away without checking
        # the regular expressions. If we check each regular expression,
        # Regexp#=== will call NilClass#to_str, which will trigger
        # method_missing (defined by whiny nil in ActiveSupport) which
        # makes this method very very slow.
        return default unless default

        case default
          when /\A'(.*)'::(num|date|tstz|ts|int4|int8)range\z/m
            $1
          # Numeric types
          when /\A\(?(-?\d+(\.\d*)?\)?(::bigint)?)\z/
            $1
          # Character types
          when /\A\(?'(.*)'::.*\b(?:character varying|bpchar|text)\z/m
            $1.gsub(/''/, "'")
          # Binary data types
          when /\A'(.*)'::bytea\z/m
            $1
          # Date/time types
          when /\A'(.+)'::(?:time(?:stamp)? with(?:out)? time zone|date)\z/
            $1
          when /\A'(.*)'::interval\z/
            $1
          # Boolean type
          when 'true'
            true
          when 'false'
            false
          # Geometric types
          when /\A'(.*)'::(?:point|line|lseg|box|"?path"?|polygon|circle)\z/
            $1
          # Network address types
          when /\A'(.*)'::(?:cidr|inet|macaddr)\z/
            $1
          # Bit string types
          when /\AB'(.*)'::"?bit(?: varying)?"?\z/
            $1
          # XML type
          when /\A'(.*)'::xml\z/m
            $1
          # Arrays
          when /\A'(.*)'::"?\D+"?\[\]\z/
            $1
          # Hstore
          when /\A'(.*)'::hstore\z/
            $1
          # JSON
          when /\A'(.*)'::json\z/
            $1
          # Object identifier types
          when /\A-?\d+\z/
            $1
          else
            # Anything else is blank, some user type, or some function
            # and we can't know the value of that, so return nil.
            nil
        end
      end

      def type_cast_for_write(value)
        if @oid_type.respond_to?(:type_cast_for_write)
          @oid_type.type_cast_for_write(value)
        else
          super
        end
      end

      def type_cast(value)
        return if value.nil?
        return super if encoded?

        @oid_type.type_cast value
      end

      def accessor
        @oid_type.accessor
      end

      private

        def has_default_function?(default_value, default)
          !default_value && (%r{\w+\(.*\)} === default)
        end

        def extract_limit(sql_type)
          case sql_type
          when /^bigint/i;    8
          when /^smallint/i;  2
          when /^timestamp/i; nil
          else super
          end
        end

        # Extracts the scale from PostgreSQL-specific data types.
        def extract_scale(sql_type)
          # Money type has a fixed scale of 2.
          sql_type =~ /^money/ ? 2 : super
        end

        # Extracts the precision from PostgreSQL-specific data types.
        def extract_precision(sql_type)
          if sql_type == 'money'
            self.class.money_precision
          elsif sql_type =~ /timestamp/i
            $1.to_i if sql_type =~ /\((\d+)\)/
          else
            super
          end
        end

        # Maps PostgreSQL-specific data types to logical Rails types.
        def simplified_type(field_type)
          @oid_type.simplified_type(field_type) || super
        end
    end
  end
end
