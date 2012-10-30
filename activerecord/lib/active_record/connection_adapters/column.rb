require 'set'

module ActiveRecord
  # :stopdoc:
  module ConnectionAdapters
    # An abstract definition of a column in a table.
    class Column
      TRUE_VALUES = [true, 1, '1', 't', 'T', 'true', 'TRUE', 'on', 'ON'].to_set
      FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF'].to_set

      module Format
        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        ISO_DATETIME = /\A(\d{4})-(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)(\.\d+)?\z/
      end

      attr_reader :name, :default, :type, :limit, :null, :sql_type, :precision, :scale
      attr_accessor :primary, :coder

      alias :encoded? :coder

      # Instantiates a new column in the table.
      #
      # +name+ is the column's name, such as <tt>supplier_id</tt> in <tt>supplier_id int(11)</tt>.
      # +default+ is the type-casted default value, such as +new+ in <tt>sales_stage varchar(20) default 'new'</tt>.
      # +sql_type+ is used to extract the column's length, if necessary. For example +60+ in
      # <tt>company_name varchar(60)</tt>.
      # It will be mapped to one of the standard Rails SQL types in the <tt>type</tt> attribute.
      # +null+ determines if this column allows +NULL+ values.
      def initialize(name, default, sql_type = nil, null = true)
        @name      = name
        @sql_type  = sql_type
        @null      = null
        @limit     = extract_limit(sql_type)
        @precision = extract_precision(sql_type)
        @scale     = extract_scale(sql_type)
        @type      = simplified_type(sql_type)
        @default   = extract_default(default)
        @primary   = nil
        @coder     = nil
      end

      # Returns +true+ if the column is either of type string or text.
      def text?
        type == :string || type == :text
      end

      # Returns +true+ if the column is either of type integer, float or decimal.
      def number?
        type == :integer || type == :float || type == :decimal
      end

      def has_default?
        !default.nil?
      end

      # Returns the Ruby class that corresponds to the abstract data type.
      def klass
        case type
        when :integer                     then Fixnum
        when :float                       then Float
        when :decimal                     then BigDecimal
        when :datetime, :timestamp, :time then Time
        when :date                        then Date
        when :text, :string, :binary      then String
        when :boolean                     then Object
        end
      end

      # Casts value (which is a String) to an appropriate instance.
      def type_cast(value)
        return nil if value.nil?
        return coder.load(value) if encoded?

        klass = self.class

        case type
        when :string, :text        then value
        when :integer              then klass.value_to_integer(value)
        when :float                then value.to_f
        when :decimal              then klass.value_to_decimal(value)
        when :datetime, :timestamp then klass.string_to_time(value)
        when :time                 then klass.string_to_dummy_time(value)
        when :date                 then klass.string_to_date(value)
        when :binary               then klass.binary_to_string(value)
        when :boolean              then klass.value_to_boolean(value)
        else value
        end
      end

      def type_cast_code(var_name)
        klass = self.class.name

        case type
        when :string, :text        then var_name
        when :integer              then "#{klass}.value_to_integer(#{var_name})"
        when :float                then "#{var_name}.to_f"
        when :decimal              then "#{klass}.value_to_decimal(#{var_name})"
        when :datetime, :timestamp then "#{klass}.string_to_time(#{var_name})"
        when :time                 then "#{klass}.string_to_dummy_time(#{var_name})"
        when :date                 then "#{klass}.string_to_date(#{var_name})"
        when :binary               then "#{klass}.binary_to_string(#{var_name})"
        when :boolean              then "#{klass}.value_to_boolean(#{var_name})"
        else var_name
        end
      end

      # Returns the human name of the column name.
      #
      # ===== Examples
      #  Column.new('sales_stage', ...).human_name # => 'Sales stage'
      def human_name
        Base.human_attribute_name(@name)
      end

      def extract_default(default)
        type_cast(default)
      end

      # Used to convert from Strings to BLOBs
      def string_to_binary(value)
        self.class.string_to_binary(value)
      end

      class << self
        # Used to convert from Strings to BLOBs
        def string_to_binary(value)
          value
        end

        # Used to convert from BLOBs to Strings
        def binary_to_string(value)
          value
        end

        def string_to_date(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_date(string) || fallback_string_to_date(string)
        end

        def string_to_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          fast_string_to_time(string) || fallback_string_to_time(string)
        end

        def string_to_dummy_time(string)
          return string unless string.is_a?(String)
          return nil if string.empty?

          dummy_time_string = "2000-01-01 #{string}"

          fast_string_to_time(dummy_time_string) || begin
            time_hash = Date._parse(dummy_time_string)
            return nil if time_hash[:hour].nil?
            new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
          end
        end

        # convert something to a boolean
        def value_to_boolean(value)
          if value.is_a?(String) && value.blank?
            nil
          else
            TRUE_VALUES.include?(value)
          end
        end

        # Used to convert values to integer.
        # handle the case when an integer column is used to store boolean values
        def value_to_integer(value)
          case value
          when TrueClass, FalseClass
            value ? 1 : 0
          else
            value.to_i
          end
        end

        # convert something to a BigDecimal
        def value_to_decimal(value)
          # Using .class is faster than .is_a? and
          # subclasses of BigDecimal will be handled
          # in the else clause
          if value.class == BigDecimal
            value
          elsif value.respond_to?(:to_d)
            value.to_d
          else
            value.to_s.to_d
          end
        end

        protected
          # '0.123456' -> 123456
          # '1.123456' -> 123456
          def microseconds(time)
            time[:sec_fraction] ? (time[:sec_fraction] * 1_000_000).to_i : 0
          end

          def new_date(year, mon, mday)
            if year && year != 0
              Date.new(year, mon, mday) rescue nil
            end
          end

          def new_time(year, mon, mday, hour, min, sec, microsec)
            # Treat 0000-00-00 00:00:00 as nil.
            return nil if year.nil? || (year == 0 && mon == 0 && mday == 0)

            Time.time_with_datetime_fallback(Base.default_timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
          end

          def fast_string_to_date(string)
            if string =~ Format::ISO_DATE
              new_date $1.to_i, $2.to_i, $3.to_i
            end
          end

          if RUBY_VERSION >= '1.9'
            # Doesn't handle time zones.
            def fast_string_to_time(string)
              if string =~ Format::ISO_DATETIME
                microsec = ($7.to_r * 1_000_000).to_i
                new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
              end
            end
          else
            def fast_string_to_time(string)
              if string =~ Format::ISO_DATETIME
                microsec = ($7.to_f * 1_000_000).round.to_i
                new_time $1.to_i, $2.to_i, $3.to_i, $4.to_i, $5.to_i, $6.to_i, microsec
              end
            end
          end

          def fallback_string_to_date(string)
            new_date(*::Date._parse(string, false).values_at(:year, :mon, :mday))
          end

          def fallback_string_to_time(string)
            time_hash = Date._parse(string)
            time_hash[:sec_fraction] = microseconds(time_hash)

            new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
          end
      end

      private
        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def extract_precision(sql_type)
          $2.to_i if sql_type =~ /^(numeric|decimal|number)\((\d+)(,\d+)?\)/i
        end

        def extract_scale(sql_type)
          case sql_type
            when /^(numeric|decimal|number)\((\d+)\)/i then 0
            when /^(numeric|decimal|number)\((\d+)(,(\d+))\)/i then $4.to_i
          end
        end

        def simplified_type(field_type)
          case field_type
          when /int/i
            :integer
          when /float|double/i
            :float
          when /decimal|numeric|number/i
            extract_scale(field_type) == 0 ? :integer : :decimal
          when /datetime/i
            :datetime
          when /timestamp/i
            :timestamp
          when /time/i
            :time
          when /date/i
            :date
          when /clob/i, /text/i
            :text
          when /blob/i, /binary/i
            :binary
          when /char/i, /string/i
            :string
          when /boolean/i
            :boolean
          end
        end
    end
  end
  # :startdoc:
end
