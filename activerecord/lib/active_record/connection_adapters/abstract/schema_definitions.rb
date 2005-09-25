module ActiveRecord
  module ConnectionAdapters #:nodoc:
    class Column #:nodoc:
      attr_reader :name, :default, :type, :limit, :null
      # The name should contain the name of the column, such as "name" in "name varchar(250)"
      # The default should contain the type-casted default of the column, such as 1 in "count int(11) DEFAULT 1"
      # The type parameter should either contain :integer, :float, :datetime, :date, :text, or :string
      # The sql_type is just used for extracting the limit, such as 10 in "varchar(10)"
      def initialize(name, default, sql_type = nil, null = true)
        @name, @type, @null = name, simplified_type(sql_type), null
        # have to do this one separately because type_cast depends on #type
        @default = type_cast(default)
        @limit = extract_limit(sql_type) unless sql_type.nil?
      end

      def klass
        case type
          when :integer       then Fixnum
          when :float         then Float
          when :datetime      then Time
          when :date          then Date
          when :timestamp     then Time
          when :time          then Time
          when :text, :string then String
          when :binary        then String
          when :boolean       then Object
        end
      end

      def type_cast(value)
        if value.nil? then return nil end
        case type
          when :string    then value
          when :text      then value
          when :integer   then value.to_i rescue value ? 1 : 0
          when :float     then value.to_f
          when :datetime  then string_to_time(value)
          when :timestamp then string_to_time(value)
          when :time      then string_to_dummy_time(value)
          when :date      then string_to_date(value)
          when :binary    then binary_to_string(value)
          when :boolean   then value == true or (value =~ /^t(rue)?$/i) == 0 or value.to_s == '1'
          else value
        end
      end

      def human_name
        Base.human_attribute_name(@name)
      end

      def string_to_binary(value)
        value
      end

      def binary_to_string(value)
        value
      end

      private
        def string_to_date(string)
          return string unless string.is_a?(String)
          date_array = ParseDate.parsedate(string.to_s)
          # treat 0000-00-00 as nil
          Date.new(date_array[0], date_array[1], date_array[2]) rescue nil
        end

        def string_to_time(string)
          return string unless string.is_a?(String)
          time_array = ParseDate.parsedate(string.to_s).compact
          # treat 0000-00-00 00:00:00 as nil
          Time.send(Base.default_timezone, *time_array) rescue nil
        end

        def string_to_dummy_time(string)
          return string unless string.is_a?(String)
          time_array = ParseDate.parsedate(string.to_s)
          # pad the resulting array with dummy date information
          time_array[0] = 2000; time_array[1] = 1; time_array[2] = 1;
          Time.send(Base.default_timezone, *time_array) rescue nil
        end

        def extract_limit(sql_type)
          $1.to_i if sql_type =~ /\((.*)\)/
        end

        def simplified_type(field_type)
          case field_type
            when /int/i
              :integer
            when /float|double|decimal|numeric/i
              :float
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
    
    class IndexDefinition < Struct.new(:table, :name, :unique, :columns) #:nodoc:
    end

    class ColumnDefinition < Struct.new(:base, :name, :type, :limit, :default, :null) #:nodoc:
      def to_sql
        column_sql = "#{name} #{type_to_sql(type.to_sym, limit)}"
        add_column_options!(column_sql, :null => null, :default => default)
        column_sql
      end
      alias to_s :to_sql
      
      private
        def type_to_sql(name, limit)
          base.type_to_sql(name, limit) rescue name
        end   

        def add_column_options!(sql, options)
          base.add_column_options!(sql, options.merge(:column => self))
        end
    end

    class TableDefinition #:nodoc:
      attr_accessor :columns

      def initialize(base)
        @columns = []
        @base = base
      end

      def primary_key(name)
        column(name, native[:primary_key])
      end
      
      def [](name)
        @columns.find {|column| column.name == name}
      end

      def column(name, type, options = {})
        column = self[name] || ColumnDefinition.new(@base, name, type)
        column.limit = options[:limit] || native[type.to_sym][:limit] if options[:limit] or native[type.to_sym]
        column.default = options[:default]
        column.null = options[:null]
        @columns << column unless @columns.include? column
        self
      end
            
      def to_sql
        @columns * ', '
      end
      
      private
        def native
          @base.native_database_types
        end
    end
  end
end